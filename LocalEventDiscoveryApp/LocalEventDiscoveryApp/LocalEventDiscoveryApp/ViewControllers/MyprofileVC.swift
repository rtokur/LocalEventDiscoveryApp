//
//  MyprofileVC.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 16.11.2024.
//
import UIKit
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FirebaseFirestore
import FirebaseStorage
import SDWebImage

class MyprofileVC: UIViewController,UITableViewDelegate,UITableViewDataSource,UIImagePickerControllerDelegate & UINavigationControllerDelegate{
    // MARK: - Properties
    var originalName: String = ""
    var originalEmail: String = ""
    var originalPhone: String = ""
    var originalProfileImage: UIImage?
    var userId: String = Auth.auth().currentUser?.uid ?? ""
    let db = Firestore.firestore()
    var favoriteEvents: [Event] = []
    var originalPreferences: [String: Bool] = [:]
    var joinedEvents: [Eventt] = []

    // MARK: - Outlets
    @IBOutlet weak var joinedEventTableView: UITableView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var eventUpdateSwitch: UISwitch!
    @IBOutlet weak var saveChangesButton: UIButton!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var phoneText: UITextField!
    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var profileButton: UIButton!
    @IBOutlet weak var notificationButton: UIButton!
    @IBOutlet weak var joinedEventsButton: UIButton!
    @IBOutlet weak var joinedEventsView: UIView!
    @IBOutlet weak var notificationView: UIView!
    @IBOutlet weak var profileView: UIView!
    @IBOutlet weak var favoriteTableView: UITableView!
    @IBOutlet weak var generalSwitch: UISwitch!
    
    // MARK: - Genel Ayar Switch'ini Değiştiren İşlev
    @IBAction func generalSwitch(_ sender: Any) {
        checkForChanges2()
    }

    // MARK: - E-posta Metin Alanında Değişiklik Yapıldığında Çağrılacak İşlev
    @IBAction func emailText(_ sender: UITextField) {
        checkForChanges()
    }

    // MARK: - Etkinlik Güncellemeleri İçin Switch Butonunun İşlevi
    @IBAction func eventUpdateSwitch(_ sender: Any) {
        checkForChanges2()
    }
    
    // MARK: - Değişiklikleri Kaydetmek İçin Butonun İşlevi
    @IBAction func saveButton(_ sender: Any) {
        let preferences: [String: Bool] = [
            "general": generalSwitch.isOn,
            "eventUpdates": eventUpdateSwitch.isOn
        ]
        
        db.collection("UserInfo").document(userId).setData(["notifications": preferences], merge: true) { error in
            if let error = error {
                self.makeAlert(title: "Hata", message: "Bildirim ayarları kaydedilemedi: \(error.localizedDescription)")
            } else {
                self.makeAlert(title: "Başarılı", message: "Bildirim ayarlarınız güncellendi.")
                self.saveButton.isHidden = true  // Kaydet butonunu gizle
            }
        }
        loadNotificationPreferences()
    }
    
    // MARK: - Kullanıcı Adı Metin Alanında Değişiklik Yapıldığında Çağrılacak İşlev
    @IBAction func nameText(_ sender: UITextField) {
        checkForChanges()
    }
    
    // MARK: - Telefon Numarası Metin Alanında Değişiklik Yapıldığında Çağrılacak İşlev
    @IBAction func phoneText(_ sender: UITextField) {
        checkForChanges()
    }
    
    // MARK: - Profil Butonuna Tıklanma İşlevi
    @IBAction func profileButton(_ sender: Any) {
        profileButton.backgroundColor = UIColor.systemGray6
        profileButton.configuration?.baseForegroundColor = UIColor.black
        profileView.isHidden = false
        profileView.layer.cornerRadius = 10
        profileButton.layer.cornerRadius = 10
        joinedEventsView.isHidden = true
        joinedEventsButton.backgroundColor = UIColor.clear
        joinedEventsButton.configuration?.baseForegroundColor = .white
        notificationView.isHidden = true
        notificationButton.backgroundColor = UIColor.clear
        notificationButton.configuration?.baseForegroundColor = .white
    }
    
    // MARK: - Bildirimler Butonuna Tıklanma İşlevi
    @IBAction func notificationButton(_ sender: Any) {
        notificationButton.backgroundColor = UIColor.systemGray6
        notificationButton.configuration?.baseForegroundColor = UIColor.black
        notificationView.isHidden = false
        notificationView.layer.cornerRadius = 10
        notificationButton.layer.cornerRadius = 10
        profileView.isHidden = true
        profileButton.backgroundColor = UIColor.clear
        profileButton.configuration?.baseForegroundColor = .white
        joinedEventsView.isHidden = true
        joinedEventsButton.backgroundColor = UIColor.clear
        joinedEventsButton.configuration?.baseForegroundColor = .white
    }
    
    // MARK: - Profil Resmini Firebase Storage'a Yüklemek İçin Buton İşlevi
    @IBAction func saveChangesButton(_ sender: Any) {
        guard let userID = Auth.auth().currentUser?.uid else {
            print("Kullanıcı oturumu açık değil.")
            return
        }
            
        // Firebase Storage referansı
        let storageRef = Storage.storage().reference().child("profilePictures/\(userID).jpg")
            
        // Profil resmini UIImage'den Data'ya çevir
        guard let profileImageData = profileImageView.image?.jpegData(compressionQuality: 0.5) else {
            self.makeAlert(title: "Hata", message: "Profil resmi bulunamadı.")
            return
        }
            
        // Görseli Firebase Storage'a yükle
        storageRef.putData(profileImageData, metadata: nil) { metadata, error in
            if let error = error {
                self.makeAlert(title: "Hata", message: "Resim yüklenemedi: \(error.localizedDescription)")
                return
            }
                
            // Yükleme tamamlandı, URL'yi al
            storageRef.downloadURL { url, error in
                if let error = error {
                    self.makeAlert(title: "Hata", message: "Resim URL'si alınamadı: \(error.localizedDescription)")
                    return
                }
                    
                guard let profilePictureUrl = url?.absoluteString else {
                    self.makeAlert(title: "Hata", message: "Resim URL'si alınamadı.")
                    return
                }
                    
                // Kullanıcı verisi
                let updatedData: [String: Any] = [
                    "name": self.nameText.text ?? "",
                    "email": self.emailText.text ?? "",
                    "phone": self.phoneText.text ?? "",
                    "profilePictureURL": profilePictureUrl
                ]
                    
                // Firestore'daki verileri güncelle
                self.db.collection("UserInfo").document(userID).setData(updatedData, merge: true) { error in
                    if let error = error {
                        self.makeAlert(title: "Hata", message: "Veriler güncellenirken hata oluştu: \(error.localizedDescription)")
                    } else {
                        self.makeAlert(title: "Başarılı", message: "Bilgileriniz güncellendi.")
                    }
                }
            }
        }
        
    }

    // MARK: - Katıldığınız Etkinlikler Butonuna Tıklanma İşlevi
    @IBAction func joinedEvents(_ sender: Any) {
        joinedEventsButton.backgroundColor = UIColor.systemGray6
        joinedEventsButton.configuration?.baseForegroundColor = UIColor.black
        joinedEventsView.isHidden = false
        joinedEventsView.layer.cornerRadius = 10
        joinedEventsButton.layer.cornerRadius = 10
        profileView.isHidden = true
        profileButton.backgroundColor = UIColor.clear
        profileButton.configuration?.baseForegroundColor = .white
        notificationView.isHidden = true
        notificationButton.backgroundColor = UIColor.clear
        notificationButton.configuration?.baseForegroundColor = .white
    }

    // MARK: - Çıkış Yap Butonuna Tıklanma İşlevi
    @IBAction func logOutButton(_ sender: Any) {
        let alert = UIAlertController(title: "Çıkış Yap", message: "Hesabınızdan çıkış yapmak istediğinize emin misiniz?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Evet", style: .destructive, handler: { _ in
            do {
                try Auth.auth().signOut() // Firebase çıkışı
                GIDSignIn.sharedInstance.signOut() // Google çıkışı
                // Çıkış yaptıktan sonra rootViewController'ı login ekranına set et
                if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                    sceneDelegate.window?.rootViewController = self.createSignInViewController()
                }
            } catch {
                print("Çıkış işlemi sırasında hata oluştu: \(error.localizedDescription)")
            }
        }))
        alert.addAction(UIAlertAction(title: "Hayır", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }

    func createSignInViewController() -> UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        return storyboard.instantiateViewController(identifier: "SignInVC") // Giriş ekranınızın identifier'ı
    }


    // MARK: - Structs
    struct Event {
        let title: String
        let date: String
    }

    struct Eventt {
        var eventId: String
        var eventName: String
        var eventDate: String
        var imageUrl: String
    }

    // MARK: - UITableView DataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == favoriteTableView {
            return favoriteEvents.count
        } else if tableView == joinedEventTableView {
            return joinedEvents.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == favoriteTableView {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "FavoriteEventCell", for: indexPath) as? FavoriteEventCell else {
                fatalError("FavoriteEventCell bulunamadı.")
            }
            let event = favoriteEvents[indexPath.row]
            cell.eventNameLabel.text = event.title
            cell.eventDateLabel.text = event.date
            return cell
        } else if tableView == joinedEventTableView {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "JoinedEventCell", for: indexPath) as? JoinedEventCell else {
                fatalError("JoinedEventCell bulunamadı.")
            }
            let event = joinedEvents[indexPath.row]
            
            // Etkinlik adı ve tarihini hücrede göster
            cell.jEventNameLabel.text = event.eventName
            cell.jEventDateLabel.text = event.eventDate
            
            // Görseli yükle
            if let imageUrl = URL(string: event.imageUrl) {
                cell.eventImageView.sd_setImage(with: imageUrl, placeholderImage: UIImage(named: "signinbackground"))
            }
            return cell
        }
        return UITableViewCell()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // MARK: - TableView Setup
        joinedEventTableView.dataSource = self
        joinedEventTableView.delegate = self
        favoriteTableView.delegate = self
        favoriteTableView.dataSource = self
        
        // MARK: - Data Loading
        loadJoinedEvents()
        loadProfileData()
        loadNotificationPreferences()
        
        // MARK: - Gesture Recognizers
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
        profileImageView.isUserInteractionEnabled = true
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(choosePicture))
        profileImageView.addGestureRecognizer(gestureRecognizer)
        
        // MARK: - UI Customizations
        profileButton.sendActions(for: .touchUpInside)
        saveChangesButton.isHidden = true
        saveButton.isHidden = true
        profileView.layer.cornerRadius = 10
        // MARK: - TextField Styling
        styleTextFieldBottomLine(for: emailText, color: UIColor.purple.cgColor)
        styleTextFieldBottomLine(for: nameText, color: UIColor.purple.cgColor)
        styleTextFieldBottomLine(for: phoneText, color: UIColor.purple.cgColor)
        
        // MARK: - UISwitch Customizations
        applyGradientToSwitch(generalSwitch)
        applyGradientToSwitch(eventUpdateSwitch)
    }
    
    // MARK: - Helper Methods
    private func styleTextFieldBottomLine(for textField: UITextField, color: CGColor) {
        let bottomLine = CALayer()
        bottomLine.frame = CGRect(x: 0, y: textField.frame.height - 1, width: textField.frame.width, height: 1)
        bottomLine.backgroundColor = color
        textField.layer.addSublayer(bottomLine)
    }
    
    // MARK: - Event Fetching and Loading
    func fetchEventDetails(eventId: String, completion: @escaping (Eventt) -> Void) {
        db.collection("Events").document(eventId).getDocument { snapshot, error in
            if let error = error {
                print("Etkinlik bilgisi alınırken hata oluştu: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                let eventName = data["name"] as? String ?? "Bilinmeyen Etkinlik"
                var eventDate = "Tarih Bilinmiyor"
                let imageUrl = data["imageUrl"] as? String ?? "" // Görsel URL'sini al
                
                if let dateString = data["date"] as? String {
                    // Eğer tarih String formatındaysa
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // JSON tarih formatı
                    formatter.locale = Locale(identifier: "tr_TR")
                    if let date = formatter.date(from: dateString) {
                        let dateFormatter = DateFormatter()
                        dateFormatter.dateStyle = .full
                        dateFormatter.timeStyle = .short
                        dateFormatter.locale = Locale(identifier: "tr_TR")
                        eventDate = dateFormatter.string(from: date)
                    }
                }
                
                let event = Eventt(eventId: eventId, eventName: eventName, eventDate: eventDate, imageUrl: imageUrl)
                completion(event)
            }
        }
    }
    
    func loadJoinedEvents() {
        db.collection("Participations")
            .whereField("userId", isEqualTo: userId) // Kullanıcı ID'sine göre katılım verilerini sorgula
            .getDocuments { snapshot, error in
                if let error = error {
                    self.makeAlert(title: "Hata", message: "Etkinlikler yüklenemedi: \(error.localizedDescription)")
                    return
                }
                
                // Katıldığı etkinliklerin verilerini al
                var events: [Eventt] = []
                for document in snapshot!.documents {
                    let data = document.data()
                    if let eventId = data["eventId"] as? String {
                        // Etkinlik ID'sini kullanarak etkinlik bilgilerini çek
                        self.fetchEventDetails(eventId: eventId) { event in
                            events.append(event)
                            DispatchQueue.main.async {
                                self.joinedEvents = events
                                self.joinedEventTableView.reloadData() // Tabloyu güncelle
                            }
                        }
                    }
                }
            }
    }

    // MARK: - UI Customizations
    func applyGradientToSwitch(_ uiSwitch: UISwitch) {
        // Gradient oluştur
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.systemPink.cgColor, UIColor.systemBlue.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        gradientLayer.frame = uiSwitch.bounds
        gradientLayer.cornerRadius = uiSwitch.bounds.height / 2

        // Gradient'i bir UIImage'e dönüştür
        UIGraphicsBeginImageContext(gradientLayer.bounds.size)
        gradientLayer.render(in: UIGraphicsGetCurrentContext()!)
        let gradientImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        // UISwitch'in "on" durumunda gradient görünümü ayarla
        uiSwitch.onTintColor = UIColor(patternImage: gradientImage!)
    }
    
    // MARK: - Image Picker
    @objc func choosePicture() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        self.present(picker, animated: true)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        profileImageView.image = info[.originalImage] as? UIImage
        self.dismiss(animated: true)
        checkForChanges()
    }
    
    // MARK: - Preference Checking
    func checkForChanges2() {
        // Değişiklik olup olmadığını kontrol et
        let isChanged = generalSwitch.isOn != (originalPreferences["general"] ?? false) ||
                        eventUpdateSwitch.isOn != (originalPreferences["eventUpdates"] ?? false)
        saveButton.isHidden = !isChanged // Değişiklik yoksa kaydet butonunu gizle
    }
    
    // MARK: - Change Detection
    func checkForChanges() {
        let isChanged = nameText.text != originalName ||
                        emailText.text != originalEmail ||
                        phoneText.text != originalPhone ||
                        !areImagesEqual(image1: profileImageView.image, image2: originalProfileImage)
        saveChangesButton.isHidden = !isChanged
    }

    func areImagesEqual(image1: UIImage?, image2: UIImage?) -> Bool {
        guard let data1 = image1?.pngData(), let data2 = image2?.pngData() else {
            return false
        }
        return data1 == data2
    }
    
    // MARK: - Notification Preferences
    func loadNotificationPreferences() {
        db.collection("UserInfo").document(userId).getDocument { snapshot, error in
            if let error = error {
                self.makeAlert(title: "Hata", message: "Bildirim ayarları yüklenemedi: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data(), let notifications = data["notifications"] as? [String: Bool] {
                self.originalPreferences = notifications
                
                DispatchQueue.main.async {
                    self.generalSwitch.isOn = notifications["general"] ?? false
                    self.eventUpdateSwitch.isOn = notifications["eventUpdates"] ?? false
                    self.updateSaveButtonVisibility()  // Kaydet butonunu güncelle
                }
            }
        }
    }
    
    // MARK: - Profile Data Loading
    func loadProfileData() {
        db.collection("UserInfo").document(userId).getDocument { snapshot, error in
            if let error = error {
                self.makeAlert(title: "Hata", message: "Profil bilgileri alınamadı: \(error.localizedDescription)")
                return
            }
            
            if let data = snapshot?.data() {
                self.originalName = data["name"] as? String ?? "Ad Yok"
                self.originalEmail = data["email"] as? String ?? "E-posta Yok"
                self.originalPhone = data["phone"] as? String ?? "Telefon Yok"
                if let profilePictureUrl = data["profilePictureURL"] as? String {
                    let url = URL(string: profilePictureUrl)
                    URLSession.shared.dataTask(with: url!) { data, _, error in
                        if let data = data {
                            let image = UIImage(data: data)
                            DispatchQueue.main.async {
                                self.profileImageView.image = image
                                self.originalProfileImage = image
                            }
                        }
                    }.resume()
                }
                
                DispatchQueue.main.async {
                    self.nameText.text = self.originalName
                    self.emailText.text = self.originalEmail
                    self.phoneText.text = self.originalPhone
                }
            }
        }
    }

    // MARK: - View Lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadFavoriteEvents()
        loadJoinedEvents()
    }
    
    // MARK: - Klavye Kapatma
    @objc func dismissKeyboard() {
        view.endEditing(true) // Klavyeyi kapatır
    }
    
    // MARK: - Favori Etkinlikleri Getirme
    func loadFavoriteEvents() {
        db.collection("UserInfo").document(userId).collection("favorites").getDocuments { snapshot, error in
            guard let documents = snapshot?.documents else {
                print("Favoriler alınamadı.")
                return
            }
            
            let eventIds = documents.compactMap { $0.data()["eventId"] as? String }
            
            self.favoriteEvents = [] // Favoriler listesini sıfırla
            let eventsCollection = self.db.collection("Events")
            let dispatchGroup = DispatchGroup()
            
            for eventId in eventIds {
                dispatchGroup.enter()
                eventsCollection.document(eventId).getDocument { eventSnapshot, eventError in
                    
                    if let eventData = eventSnapshot?.data() {
                        let title = eventData["name"] as? String ?? "Bilinmeyen Etkinlik"
                        
                        if let dateString = eventData["date"] as? String {
                            // Tarih formatlayıcı oluştur
                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                            dateFormatter.locale = Locale(identifier: "tr_TR")
                            
                            if let date = dateFormatter.date(from: dateString) {
                                // Tarihi yerel saat dilimine göre biçimlendir
                                let outputFormatter = DateFormatter()
                                outputFormatter.dateStyle = .full
                                outputFormatter.timeStyle = .short
                                outputFormatter.locale = Locale(identifier: "tr_TR")
                                
                                let formattedDate = outputFormatter.string(from: date)
                                self.favoriteEvents.append(Event(title: title, date: formattedDate))
                            } else {
                                self.favoriteEvents.append(Event(title: title, date: "Tarih Geçersiz"))
                            }
                        } else {
                            self.favoriteEvents.append(Event(title: title, date: "Tarih Yok"))
                        }
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.favoriteTableView.reloadData()
            }
        }
    }
    
    // MARK: -Tablo Hücre Yüksekliği
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if tableView == favoriteTableView {
            return 60
        }else if tableView == joinedEventTableView {
            return 280
        }
        return 0
    }
    
    // MARK: -Uyarı Ekranı
    func makeAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        present(alert, animated: true)
    }
    
    // MARK: - Kaydet Butonunun Görünürlüğünü Güncelleyen İşlev
    func updateSaveButtonVisibility() {
        // Kaydet butonunun görünürlüğünü güncelle
        let isChanged = generalSwitch.isOn != (originalPreferences["general"] ?? false) || eventUpdateSwitch.isOn != (originalPreferences["eventUpdates"] ?? false)
        saveButton.isHidden = !isChanged  // Kaydet butonunu gizle
    }
}
