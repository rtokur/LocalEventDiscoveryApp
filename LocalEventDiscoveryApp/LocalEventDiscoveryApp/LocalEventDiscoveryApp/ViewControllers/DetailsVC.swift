//
//  DetailsVC.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 18.11.2024.
//

import UIKit
import SDWebImage
import FirebaseFirestore
import FirebaseAuth
import EventKit
import EventKitUI
import Cosmos
import MapKit

class DetailsVC: UIViewController {

    // MARK: - IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var cosmosView: CosmosView!
    @IBOutlet weak var detailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var addToCalendarButton: UIButton!
    @IBOutlet weak var addFavoritesButton: UIButton!
    @IBOutlet weak var categoryLabel: UILabel!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var participateButton: UIButton!
    @IBOutlet weak var detailView: UIView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var seeCommentButton: UIButton!
    @IBOutlet weak var dateLabel: UILabel!
    
    // MARK: - Properties
    var event: Event?
    
    
    // MARK: - IBActions
    @IBAction func seeCommentButton(_ sender: Any) {
        if let event = event {
            performSegue(withIdentifier: "showComments", sender: event)
        }
    }
    
    @IBAction func addFavoritesButton(_ sender: Any) {
        // Favorilere ekle buton animasyonu
        UIView.animate(withDuration: 0.2, animations: {
            self.addFavoritesButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)  // Butonu büyüt
        }) { _ in
            UIView.animate(withDuration: 0.2) {
                self.addFavoritesButton.transform = CGAffineTransform.identity  // Butonu eski haline getir
            }
        }

        // Favori durumunu değiştir
        if let eventId = event?.id {
            toggleFavoriteStatus(eventID: eventId)
        }
    }

    @IBAction func addToCalendarButton(_ sender: Any) {
        guard let event = event else { return }

        let eventStore = EKEventStore()

        eventStore.requestAccess(to: .event) { granted, error in
            if let error = error {
                print("Error requesting access: \(error.localizedDescription)")
                return
            }

            if granted {
                let calendars = eventStore.calendars(for: .event)
                let eventName = event.name ?? ""
                let eventStartDate = event.date ?? Date()
                let eventEndDate = event.date?.addingTimeInterval(120 * 60) ?? Date()

                // Aynı etkinliği arayın
                let predicate = eventStore.predicateForEvents(
                    withStart: eventStartDate,
                    end: eventEndDate,
                    calendars: calendars
                )

                let existingEvents = eventStore.events(matching: predicate).filter {
                    $0.title == eventName
                }

                if let existingEvent = existingEvents.first {
                    // Etkinlik bulundu, sil
                    do {
                        try eventStore.remove(existingEvent, span: .thisEvent, commit: true)
                        DispatchQueue.main.async {
                            self.makeAlert(title: "Başarı", message: "Etkinlik takvimden kaldırıldı!")
                        }
                    } catch let error {
                        DispatchQueue.main.async {
                            self.makeAlert(title: "Hata", message: "Etkinlik kaldırılamadı: \(error.localizedDescription)")
                        }
                    }
                } else {
                    // Etkinlik bulunamadı, ekle
                    let calendarEvent = EKEvent(eventStore: eventStore)
                    calendarEvent.title = eventName
                    calendarEvent.startDate = eventStartDate
                    calendarEvent.endDate = eventEndDate
                    calendarEvent.location = event.place
                    calendarEvent.calendar = eventStore.defaultCalendarForNewEvents

                    do {
                        try eventStore.save(calendarEvent, span: .thisEvent, commit: true)
                        DispatchQueue.main.async {
                            self.makeAlert(title: "Başarı", message: "Etkinlik takvime eklendi!")
                        }
                    } catch let error {
                        DispatchQueue.main.async {
                            self.makeAlert(title: "Hata", message: "Etkinlik eklenemedi: \(error.localizedDescription)")
                        }
                    }
                }
            } else {
                print("Access denied to events.")
                if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                    DispatchQueue.main.async {
                        UIApplication.shared.open(appSettings)
                    }
                }
            }
        }
    }


    @IBAction func addRemindersButton(_ sender: Any) {
        guard let event = event else { return }

        let eventStore = EKEventStore()

        eventStore.requestAccess(to: .reminder) { [weak self] (granted, error) in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    print("Error requesting access: \(error.localizedDescription)")
                    self.makeAlert(title: "Hata", message: "Anımsatıcı erişimi sırasında bir hata oluştu: \(error.localizedDescription)")
                }
                return
            }

            if granted {
                // Anımsatıcıların sorgulanması ve ekleme/kaldırma işlemi
                self.checkAndToggleReminder(event: event, eventStore: eventStore)
            } else {
                DispatchQueue.main.async {
                    print("Access denied to reminders.")
                    self.makeAlert(title: "Erişim Engellendi", message: "Anımsatıcılar için erişim izni verilmedi.")
                    if let appSettings = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(appSettings, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }

    private func checkAndToggleReminder(event: Event, eventStore: EKEventStore) {
        let predicate = eventStore.predicateForReminders(in: nil)

        eventStore.fetchReminders(matching: predicate) { [weak self] reminders in
            guard let self = self else { return }

            if let reminders = reminders, let existingReminder = reminders.first(where: { $0.title == event.name }) {
                // Mevcut bir anımsatıcı bulundu, kaldır
                do {
                    try eventStore.remove(existingReminder, commit: true)
                    DispatchQueue.main.async {
                        self.makeAlert(title: "Başarı", message: "Anımsatıcı kaldırıldı!")
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.makeAlert(title: "Hata", message: "Anımsatıcı kaldırılırken bir hata oluştu: \(error.localizedDescription)")
                    }
                }
            } else {
                // Mevcut bir anımsatıcı bulunamadı, ekle
                let reminder = EKReminder(eventStore: eventStore)
                reminder.title = event.name ?? "Etkinlik"
                reminder.calendar = eventStore.defaultCalendarForNewReminders()
                reminder.notes = "Yer: \(event.place ?? "Bilinmiyor")"
                reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.date ?? Date())

                do {
                    try eventStore.save(reminder, commit: true)
                    DispatchQueue.main.async {
                        self.makeAlert(title: "Başarı", message: "Anımsatıcı eklendi!")
                    }
                } catch let error {
                    DispatchQueue.main.async {
                        self.makeAlert(title: "Hata", message: "Anımsatıcı eklenirken bir hata oluştu: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    @IBAction func participateButton(_ sender: Any) {
        guard let event = event else { return }

        let db = Firestore.firestore()
        let userId = Auth.auth().currentUser?.uid ?? "unknown_user"
        let eventId = event.id ?? ""

        // Katılım sorgusu
        let query = db.collection("Participations")
            .whereField("eventId", isEqualTo: eventId)
            .whereField("userId", isEqualTo: userId)

        query.getDocuments { snapshot, error in
            if let error = error {
                self.makeAlert(title: "Error", message: "Failed to check participation: \(error.localizedDescription)")
                return
            }

            // Katılım var mı?
            if let document = snapshot?.documents.first {
                // Katılımı sil
                document.reference.delete { error in
                    if let error = error {
                        self.makeAlert(title: "Error", message: "Failed to leave event: \(error.localizedDescription)")
                    } else {
                        self.makeAlert(title: "Başarı", message: "Etkinlikten ayrıldınız!")
                    }
                }
            } else {
                // Yeni katılım ekle
                let participationData: [String: Any] = [
                    "eventId": eventId,
                    "userId": userId,
                    "timestamp": Date()
                ]

                db.collection("Participations").addDocument(data: participationData) { error in
                    if let error = error {
                        self.makeAlert(title: "Error", message: "Failed to join event: \(error.localizedDescription)")
                    } else {
                        self.makeAlert(title: "Başarı", message: "Etkinliğe katıldınız!")
                    }
                }
            }
        }
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // UI Konfigürasyonu
        configureUI()
        loadEventDetails()
            
        // Klavye gizleme jesti ekleme
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        // CosmosView Ayarları
        configureCosmosView()
    }
        
    
    // MARK: - Helper Methods
    private func configureUI() {
        detailView.layer.cornerRadius = 20
        contentView.layer.cornerRadius = 20
        detailImageView.layer.cornerRadius = 20
        applyGradientToButton(addToCalendarButton)
        applyGradientToButton(participateButton)
        applyGradientToButton(seeCommentButton)
        let colors: [UIColor] = [.systemPink,.purple]
        let colors2: [UIColor] = [.purple,.red]
        let colors3: [UIColor] = [.purple,.systemPink]
        seeCommentButton.setGradientBackground(colors: colors)
        participateButton.setGradientBackground(colors: colors2)
        addToCalendarButton.setGradientBackground(colors: colors3)
    }
    
    private func loadEventDetails() {
        guard let event = event else { return }

        titleLabel.text = event.name
        categoryLabel.text = event.category
        placeLabel.text = event.place

        if let imageUrl = URL(string: event.imageUrl ?? "") {
            detailImageView.sd_setImage(with: imageUrl, placeholderImage: UIImage(named: "placeholder"))
        }

        // Tarih ve saat formatlama
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "tr_TR")

        // Tarih
        dateFormatter.dateFormat = "dd MMMM yyyy"
        dateLabel.text = dateFormatter.string(from: event.date ?? Date())

        // Saat
        dateFormatter.dateFormat = "HH:mm"
        timeLabel.text = dateFormatter.string(from: event.date ?? Date())

        // Harita bilgisi
        if let latitude = event.latitude, let longitude = event.longitude {
            let eventLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

            let annotation = MKPointAnnotation()
            annotation.coordinate = eventLocation
            annotation.title = event.name
            annotation.subtitle = event.place

            mapView.addAnnotation(annotation)

            let region = MKCoordinateRegion(center: eventLocation, span: MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03))
                mapView.setRegion(region, animated: true)
        }
    }
    
    private func configureCosmosView() {
        cosmosView.settings.fillMode = .precise // Yıldızların doluluk oranı
        cosmosView.settings.starSize = 20  // Yıldızların boyutu
        cosmosView.settings.starMargin = 10
        cosmosView.settings.filledColor = UIColor(hex: "#cc549c")
        cosmosView.settings.filledBorderColor = UIColor(hex: "#cc549c")
        cosmosView.settings.emptyBorderColor = UIColor(hex: "#cc549c")
        cosmosView.settings.emptyBorderWidth = 2
        cosmosView.settings.filledBorderWidth = 2

        // Yıldız seçimi işleme
        cosmosView.didTouchCosmos = { [weak self] rating in
            guard let self = self else { return }
            let userId = Auth.auth().currentUser?.uid ?? "unknown_user"
            if let eventID = self.event?.id {
                self.saveRating(eventID: eventID, userID: userId, rating: rating)
            }
        }
    }

    // MARK: - Navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let navigationController = segue.destination as? UINavigationController,
           let destinationVC = navigationController.topViewController as? CommentsVC {
            if let event = sender as? Event {
                destinationVC.eventId = event.id ?? "" // eventId'yi CommentsVC'ye aktarıyoruz
                print("Event ID passed to CommentsVC: \(event.id ?? "")")  // Kontrol amacıyla print
            }
        }
    }
    
    
    // MARK: - Favorites Management
    func addEventToFavorites(eventID: String) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Kullanıcı kimliği alınamadı.")
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("UserInfo").document(userID)
        let favoritesRef = userRef.collection("favorites")

        favoritesRef.addDocument(data: ["eventId": eventID]) { error in
            if let error = error {
                print("Favori etkinlik eklenirken hata oluştu: \(error.localizedDescription)")
            } else {
                self.makeAlert(title: "Başarılı", message: "Etkinlik başarıyla favorilere eklendi.")
            }
        }
    }
    
    
    func checkIfEventIsFavorited(eventID: String, completion: @escaping (Bool) -> Void) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Kullanıcı kimliği alınamadı.")
            completion(false)
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("UserInfo").document(userID)
        let favoritesRef = userRef.collection("favorites")

        favoritesRef.whereField("eventId", isEqualTo: eventID).getDocuments { snapshot, error in
            if let error = error {
                print("Hata: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(!snapshot!.isEmpty) // Favorilerde bulunuyorsa true döner
            }
        }
    }

    func toggleFavoriteStatus(eventID: String) {
        checkIfEventIsFavorited(eventID: eventID) { isFavorited in
            if isFavorited {
                self.removeEventFromFavorites(eventID: eventID)
            } else {
                self.addEventToFavorites(eventID: eventID)
            }
        }
    }
    // Etkinliği favorilerden çıkaran fonksiyon
    func removeEventFromFavorites(eventID: String) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Kullanıcı kimliği alınamadı.")
            return
        }

        let db = Firestore.firestore()
        let userRef = db.collection("UserInfo").document(userID)
        let favoritesRef = userRef.collection("favorites")

        favoritesRef.whereField("eventId", isEqualTo: eventID).getDocuments { snapshot, error in
            if let error = error {
                print("Hata: \(error.localizedDescription)")
            } else {
                for document in snapshot!.documents {
                    document.reference.delete { error in
                        if let error = error {
                            print("Favori etkinlik silinirken hata oluştu: \(error.localizedDescription)")
                        } else {
                            self.makeAlert(title: "Başarılı", message: "Etkinlik favorilerden çıkarıldı.")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Calendar and Reminders
    func addEventToCalendar(name: String, startDate: Date, endDate: Date, location: String) {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        
        // Etkinlik bilgilerini ayarla
        event.title = name
        event.startDate = startDate
        event.endDate = endDate
        event.notes = description
        event.location = location
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        DispatchQueue.main.async {
            do {
                try eventStore.save(event, span: .thisEvent, commit: true)
                self.makeAlert(title: "Başarılı", message: "Etkinlik başarıyla takvime eklendi.")
            } catch let error {
                print("Etkinlik eklenirken hata oluştu: \(error.localizedDescription)")
            }
        }
    }

    func addReminderToReminders(event: Event, eventStore: EKEventStore) {
        let reminder = EKReminder(eventStore: eventStore)
        
        // Hatırlatıcı bilgilerini ayarla
        reminder.title = event.name
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: event.date ?? Date())
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            DispatchQueue.main.async {
                self.makeAlert(title: "Başarılı", message: "Etkinlik başarıyla anımsatıcılara eklendi.")
            }
        } catch let error {
            DispatchQueue.main.async {
                print("Error saving reminder: \(error.localizedDescription)")
                self.makeAlert(title: "Hata", message: "Anımsatıcı kaydedilirken bir hata oluştu: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - UI Enhancements
    func applyGradientToButton(_ button: UIButton) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.systemPink.cgColor, UIColor.systemBlue.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.frame = button.bounds
        gradientLayer.cornerRadius = button.bounds.height / 2

        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        gradientLayer.render(in: UIGraphicsGetCurrentContext()!)
        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        button.setBackgroundImage(gradientImage, for: .normal)
    }

    // MARK: - Keyboard Management
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Event Ratings
    func saveRating(eventID: String, userID: String, rating: Double) {
        let db = Firestore.firestore()
        let eventRef = db.collection("Events").document(eventID)
        let ratingsRef = eventRef.collection("Ratings")

        // Mevcut puanı kontrol et
        ratingsRef.whereField("userID", isEqualTo: userID).getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                print("Puan kontrol edilirken hata oluştu: \(error.localizedDescription)")
                return
            }

            if let documents = snapshot?.documents, !documents.isEmpty {
                // Daha önce puan verilmiş, puanı kaldır
                for document in documents {
                    document.reference.delete { error in
                        if let error = error {
                            print("Puan kaldırılırken hata oluştu: \(error.localizedDescription)")
                        } else {
                            self.makeAlert(title: "Puan Kaldırıldı", message: "Etkinliğe verdiğiniz puan kaldırıldı.")
                            print("Puan başarıyla kaldırıldı.")
                        }
                    }
                }
            } else {
                // Daha önce puan verilmemiş, yeni puan ekle
                ratingsRef.addDocument(data: [
                    "userID": userID,
                    "rating": rating,
                    "timestamp": FieldValue.serverTimestamp()
                ]) { error in
                    if let error = error {
                        print("Puan kaydedilirken hata oluştu: \(error.localizedDescription)")
                    } else {
                        self.makeAlert(title: "Teşekkürler", message: "Puanınız verildi.")
                        print("Puan başarıyla kaydedildi: \(rating)")
                    }
                }
            }
        }
    }


    // MARK: - Alerts
    func makeAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        present(alert, animated: true)
    }
}
extension UIButton {
    func setGradientBackground(colors: [UIColor], startPoint: CGPoint = .zero, endPoint: CGPoint = CGPoint(x: 1, y: 1)) {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        gradientLayer.frame = bounds
        
        gradientLayer.cornerRadius = 20 // Gradyan katmanı için corner radius
                
                // Önceden eklenmiş katmanları temizle (tekrar eklemeleri önlemek için)
                layer.sublayers?.removeAll(where: { $0 is CAGradientLayer })
                
                // Gradyan katmanını buton katmanına ekle
                layer.insertSublayer(gradientLayer, at: 0)
                
                // Butonun kendi köşe yuvarlamasını ayarla
                layer.cornerRadius = 20
                clipsToBounds = true
    }
}
