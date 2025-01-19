import UIKit
import Firebase
import FirebaseFirestore
import FirebaseAuth
import SDWebImage
import Foundation
import CoreLocation
class HomepageVC: UIViewController, UISearchBarDelegate,CLLocationManagerDelegate {
    
    // MARK: - Outlets
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var hiLabel: UILabel!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    
    // MARK: - Properties
    var categoryStackView: UIStackView!
    var events = [Event]() // Tüm etkinlikler
    var filteredEvents = [Event]() // Filtrelenmiş etkinlikler
    var selectedEvent : Event?
    let urlString = "https://app.ticketmaster.com/discovery/v2/events.json?apikey=V1SBmd3wbb8HqYhjF8TvQrzTn5uhQvo2&countryCode=TR&size=60"
    
    // Kategori çeviri sözlüğü
    let categoryTranslations: [String: String] = [
        "Music": "Müzik",
        "Sports": "Spor",
        "Arts & Theatre": "Sanat ve Tiyatro",
        "Festivals": "Festivaller"
    ]
    
    let locationManager = CLLocationManager()

    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        deleteExpiredEventsFromFirestore()
        

        
        // API Çağrısı
        fetchEventsFromAPI()

        // Profil resmi ayarı
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        profileImageView.clipsToBounds = true
        
        // Delegelerin atanması
        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
        
        
        // Konum yöneticisinin başlatılması
        setupLocationManager()
        
        fetchUserDataAndDisplay()
        self.navigationController?.navigationBar.isHidden = false
        
        setupSearchBar()
        setupCategoryStackView()
        fetchEventsFromFirebase()
        customizeSearchBar()
        customizeSearchBarFont()
        scrollView.isScrollEnabled = true
        
        // Yukarı çık butonunu ekrana ekle
        setUpScrollToTopButton()
        
        // Tab Bar özelleştirme
        setupTabBarItems()
        sendNotificationsToUsers()
    }
    // MARK: - API İşlemleri
        private func fetchEventsFromAPI() {
            guard let url = URL(string: urlString) else { return }
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("Error fetching data: \(error)")
                    return
                }
                
                guard let data = data else {
                    print("No data received")
                    return
                }
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let embedded = jsonResponse["_embedded"] as? [String: Any],
                       let events = embedded["events"] as? [[String: Any]] {
                        for event in events {
                            self.saveEventToFirestore(event: event)
                        }
                    }
                } catch {
                    print("Error decoding JSON: \(error)")
                }
            }
            task.resume()
        }
    // MARK: - Konum İşlemleri
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    // MARK: - Tab Bar Özelleştirme
    private func setupTabBarItems() {
        let images = ["homepage", "myprofile", "aroundme"]
        if let tabBarItems = tabBarController?.tabBar.items {
            for (index, item) in tabBarItems.enumerated() {
                item.image = UIImage(named: images[index])?.withRenderingMode(.alwaysOriginal)
                tabBarController?.tabBar.tintColor = UIColor(hex: "#9810f6")
            }
        }
    }
    // MARK: - Yukarı Çık Butonu Ayarları
    func setUpScrollToTopButton() {
        view.addSubview(scrollToTopButton)
        
        // Auto Layout
        scrollToTopButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollToTopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scrollToTopButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -110),
            scrollToTopButton.widthAnchor.constraint(equalToConstant: 50),
            scrollToTopButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Butona tıklama aksiyonu
        scrollToTopButton.addTarget(self, action: #selector(scrollToTop), for: .touchUpInside)
    }
    
    // En yukarı kaydırma işlemi
    @objc func scrollToTop() {
        tableView.setContentOffset(.zero, animated: true)
    }
    // Yukarı çık butonu
    let scrollToTopButton: UIButton = {
        let button = UIButton(type: .system)
        let iconImage = UIImage(named: "up-arrow")?.resized(to: CGSize(width: 50, height: 50))!.withRenderingMode(.alwaysOriginal) // Orijinal renkleri koru // Boyutlandırılmış görsel
        
        button.setImage(iconImage, for: .normal)
        button.backgroundColor = .white
        button.layer.cornerRadius = 40
        button.isHidden = true // İlk başta gizli
        return button
    }()
    // MARK: - Kaydırma Takibi
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Kaydırma mesafesi 300'den büyükse butonu göster
        if scrollView.contentOffset.y > 300 {
            scrollToTopButton.isHidden = false
        } else {
            scrollToTopButton.isHidden = true
        }
    }
   //MARK: - Geçmiş Etkinlikleri Silme
    func deleteExpiredEventsFromFirestore() {
        let db = Firestore.firestore()
        let now = Date() // Mevcut tarih ve saat

        // "events" koleksiyonundaki tüm belgeleri al
        db.collection("Events").getDocuments { (snapshot, error) in
            if let error = error {
                print("Etkinlikleri alırken hata oluştu: \(error)")
                return
            }

            guard let documents = snapshot?.documents else { return }

            for document in documents {
                let data = document.data()

                if let eventDateString = data["date"] as? String {
                    let dateFormatter = ISO8601DateFormatter()

                    if let eventDate = dateFormatter.date(from: eventDateString) {
                        // Etkinlik tarihi şimdiki zamandan önceyse silme işlemini başlat
                        if eventDate < now {
                            // Favorilerden ve katılım bilgilerinden kaldır
                            self.removeEventFromFavorites(eventID: document.documentID)
                            self.removeEventFromParticipations(eventID: document.documentID)
                                            
                            // Etkinliği Firestore'dan sil
                            db.collection("Events").document(document.documentID).delete { error in
                                if let error = error {
                                    print("Etkinlik silinirken hata oluştu: \(error)")
                                } else {
                                    print("Geçmiş etkinlik silindi: \(document.documentID)")
                                                    
                                    // Tabloyu güncelle
                                    DispatchQueue.main.async {
                                        self.tableView.reloadData()
                                    }
                                }
                            }
                        }
                    } else {
                        print("Geçersiz tarih formatı: \(eventDateString)")
                    }

                } else {
                    print("Tarih bilgisi eksik: \(document.documentID)")
                }
            }
        }
    }
    //MARK: - Geçmiş Etkinlikler İçin Katılımları Silme
    func removeEventFromParticipations(eventID: String) {
        let db = Firestore.firestore()

        // "Participations" koleksiyonundaki tüm belgeleri kontrol et
        db.collection("Participations").whereField("eventId", isEqualTo: eventID).getDocuments { (snapshot, error) in
            if let error = error {
                print("Katılım verileri alınırken hata oluştu: \(error)")
                return
            }

            guard let participationDocs = snapshot?.documents else { return }

            for participationDoc in participationDocs {
                // Katılım belgesini sil
                db.collection("Participations").document(participationDoc.documentID).delete { error in
                    if let error = error {
                        print("Katılım silinirken hata oluştu: \(error)")
                    } else {
                        print("Katılım verisi silindi: \(participationDoc.documentID)")
                    }
                }
            }
        }
    }
    //MARK: - Geçmiş Etkinlikler İçin Favorileri Silme
    func removeEventFromFavorites(eventID: String) {
        let db = Firestore.firestore()

        // "UserInfo" koleksiyonundaki tüm kullanıcıları kontrol et
        db.collection("UserInfo").getDocuments { (snapshot, error) in
            if let error = error {
                print("Kullanıcıları alırken hata oluştu: \(error)")
                return
            }

            guard let documents = snapshot?.documents else { return }

            for document in documents {
                let userID = document.documentID // Kullanıcı ID'si
                let favoritesRef = db.collection("UserInfo").document(userID).collection("favorites")

                // Kullanıcının favorilerinde bu etkinlik var mı kontrol et
                favoritesRef.whereField("eventId", isEqualTo: eventID).getDocuments { (snapshot, error) in
                    if let error = error {
                        print("Favoriler kontrol edilirken hata oluştu: \(error)")
                        return
                    }

                    guard let favoriteDocs = snapshot?.documents else { return }

                    for favoriteDoc in favoriteDocs {
                        // Favori etkinlik belgeyi sil
                        favoritesRef.document(favoriteDoc.documentID).delete { error in
                            if let error = error {
                                print("Favori etkinlik silinirken hata oluştu: \(error)")
                            } else {
                                print("Favorilerden etkinlik silindi: \(favoriteDoc.documentID)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    //MARK: - Konum Bilgisi Alma
    // Kullanıcının konum bilgisi başarıyla alındığında çağrılır
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Ters geocode işlemi ile şehir ve ülke bilgisi alınır
        getCityAndCountry(from: location)
        locationManager.stopUpdatingLocation()
    }
    
    //MARK: - Konum Bilgisi Hatası
    // Hata durumunda çağrılır
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Konum alınırken hata: \(error.localizedDescription)")
        self.locationLabel.text = "Konum izni verilmedi."

    }
    
    //MARK: - Arama Barını Özelleştirme
    func setupSearchBar() {
        // Arka plan rengi
        searchBar.barTintColor = UIColor.white // Arka plan rengini beyaz yapabiliriz

        // Yazı rengini değiştirme
        searchBar.setImage(UIImage(named: "search"), for: .search, state: .normal) // Arama butonunun rengi
        searchBar.searchTextField.textColor = UIColor.darkGray // Yazı rengi

        // Placeholder rengi
        searchBar.placeholder = "Etkinlik ara..."
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.attributedPlaceholder = NSAttributedString(string: "Etkinlik ara", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        }

        
        // Clear button rengi
        searchBar.searchTextField.clearButtonMode = .whileEditing
    }
    
    func customizeSearchBar() {
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.layer.cornerRadius = 20
            textField.clipsToBounds = true
        }
    }
    
    func customizeSearchBarFont() {
        if let textField = searchBar.value(forKey: "searchField") as? UITextField {
            textField.font = UIFont.systemFont(ofSize: 16) // Font boyutunu değiştirme
        }
    }
    
    //MARK: - SearcBar Arama İptali
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // Kullanıcı arama iptal ettiğinde yapılacak işlem
        searchBar.text = ""
        filteredEvents = events
        tableView.reloadData()
    }
    
    //MARK: - Kategori Görünümü Oluşturma
    func setupCategoryStackView() {
        // StackView oluştur
        categoryStackView = UIStackView()
        categoryStackView.axis = .horizontal
        categoryStackView.alignment = .center
        categoryStackView.distribution = .equalSpacing
        categoryStackView.spacing = 16 // Butonlar arası boşluk
        categoryStackView.translatesAutoresizingMaskIntoConstraints = false

        // "Tüm Kategoriler" butonunu ekle
        let allCategoriesButtonStackView = UIStackView()
        allCategoriesButtonStackView.axis = .vertical
        allCategoriesButtonStackView.alignment = .center
        allCategoriesButtonStackView.spacing = 8
        allCategoriesButtonStackView.translatesAutoresizingMaskIntoConstraints = false

        // "Tüm Kategoriler" için görseli oluştur
        let allCategoriesImageView = UIImageView()
        allCategoriesImageView.image = UIImage(named: "all") // "all_categories_image" yerine görsel adınızı yazın
        allCategoriesImageView.contentMode = .scaleAspectFit
        allCategoriesImageView.heightAnchor.constraint(equalToConstant: 50).isActive = true // Görselin yüksekliği

        // "Tüm Kategoriler" butonunu oluştur
        let allCategoriesButton = UIButton(type: .system)
        allCategoriesButton.setTitle("Tüm Kategoriler", for: .normal)
        allCategoriesButton.setTitleColor(.black, for: .normal)
        allCategoriesButton.backgroundColor = .white
        allCategoriesButton.layer.cornerRadius = 12
        allCategoriesButton.layer.shadowColor = UIColor.black.cgColor // Gölge rengini siyah yap
        allCategoriesButton.layer.shadowOffset = CGSize(width: 0, height: 4) // Gölgenin yeri
        allCategoriesButton.layer.shadowOpacity = 0.3 // Gölgenin saydamlığı
        allCategoriesButton.layer.shadowRadius = 4 // Gölgenin büyüklüğü
        allCategoriesButton.clipsToBounds = false
        allCategoriesButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        allCategoriesButton.addTarget(self, action: #selector(allCategoriesButtonTapped), for: .touchUpInside)
        
        // Görseli ve butonu stack view'e ekle
        allCategoriesButtonStackView.addArrangedSubview(allCategoriesImageView)
        allCategoriesButtonStackView.addArrangedSubview(allCategoriesButton)

        // StackView'a "Tüm Kategoriler" butonunu ekle
        categoryStackView.addArrangedSubview(allCategoriesButtonStackView)

        // Diğer kategori butonları için döngü
        for (category, translatedCategory) in categoryTranslations {
            let buttonStackView = UIStackView()
            buttonStackView.axis = .vertical
            buttonStackView.alignment = .center
            buttonStackView.spacing = 8 // Görsel ile başlık arasındaki boşluk
            buttonStackView.translatesAutoresizingMaskIntoConstraints = false

            // Kategori görselini oluştur (Assets'deki görseli kullanıyoruz)
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.image = UIImage(named: category) // Kategori ismiyle uyumlu bir görsel yükleniyor
            imageView.heightAnchor.constraint(equalToConstant: 50).isActive = true // Görselin yüksekliği

            // Buton metnini oluştur
            let button = UIButton(type: .system)
            button.setTitle(translatedCategory, for: .normal)
            button.setTitleColor(.black, for: .normal)
            button.backgroundColor = .white
            button.layer.cornerRadius = 12 // Yuvarlak köşeler
            button.layer.shadowColor = UIColor.black.cgColor // Gölge rengini siyah yap
            button.layer.shadowOffset = CGSize(width: -4, height: 4) // Gölgenin yeri
            button.layer.shadowOpacity = 0.3 // Gölgenin saydamlığı
            button.layer.shadowRadius = 4 // Gölgenin büyüklüğü
            button.clipsToBounds = false
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            button.addTarget(self, action: #selector(categoryButtonTapped(_:)), for: .touchUpInside)

            // StackView'a görsel ve buton ekleyin
            buttonStackView.addArrangedSubview(imageView)
            buttonStackView.addArrangedSubview(button)

            // Ana stackView'a buttonStackView ekleyin
            categoryStackView.addArrangedSubview(buttonStackView)
        }

        // StackView'i scrollView'in içine ekle
        scrollView.addSubview(categoryStackView)

        // Auto Layout ayarları
        NSLayoutConstraint.activate([
            categoryStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            categoryStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            categoryStackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            categoryStackView.heightAnchor.constraint(equalToConstant: 100) // Yüksekliği ayarlayabilirsiniz
        ])
    }
    
    //MARK: - Kategori Tıklanma Olayı
    @objc func categoryButtonTapped(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
                sender.transform = CGAffineTransform.identity
            }
        self.fetchEventsFilteredByCategory(category: sender.title(for: .normal))
        })
    }


    // "Tüm Kategoriler" butonuna tıklandığında çağrılacak fonksiyon
    @objc func allCategoriesButtonTapped(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1,
                       animations: {
                           sender.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                       },
                       completion: { _ in
                           UIView.animate(withDuration: 0.1) {
                               sender.transform = CGAffineTransform.identity
                           }
                        self.filteredEvents = self.events
            self.tableView.reloadData()
        })
    }

    //MARK: - Klavye Kapatma
    // Enter tuşuna basıldığında çalışır
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        // Klavyeyi kapatır
        searchBar.resignFirstResponder()
    }
    
    //MARK: - Etkinlik Bilgisini Firebase'e Kaydetme
    func saveEventToFirestore(event: [String: Any]) {
        let db = Firestore.firestore()
        
        
        if let eventId = event["id"] as? String,
           let name = event["name"] as? String,
           let dates = event["dates"] as? [String: Any],
           let start = dates["start"] as? [String: Any],
           let dateTime = start["dateTime"] as? String, // Tarih bilgisi
           let images = event["images"] as? [[String: Any]],
           let imageUrl = images.first?["url"] as? String,
           let classifications = event["classifications"] as? [[String: Any]],
           let segment = classifications.first?["segment"] as? [String: Any],
           let category = segment["name"] as? String, // Kategori bilgisi
           let embedded = event["_embedded"] as? [String: Any],
           let venues = embedded["venues"] as? [[String: Any]],
           let venue = venues.first,
           let venueName = venue["name"] as? String,
           let location = venue["location"] as? [String: Any],
           let latitudeString = location["latitude"] as? String,
           let longitudeString = location["longitude"] as? String,
           let latitude = Double(latitudeString), // latitude ve longitude String'ten Double'a dönüştürülmeli
           let longitude = Double(longitudeString) {
            
            // Event verisini Firestore'a yaz
            let eventData: [String: Any] = [
                "name": name,
                "place": venueName,
                "longitude": longitude,
                "latitude": latitude,
                "imageUrl": imageUrl,
                "date": dateTime,
                "category": category
            ]
            
            // Firestore'a veri kaydetme işlemi
            db.collection("Events").document(eventId).setData(eventData) { error in
                if let error = error {
                    print("Error writing event to Firestore: \(error.localizedDescription)")
                } else {
                    print("Event successfully written!")
                }
            }
        } else {
            print("Required data is missing or incorrectly formatted.")
        }
    }
    
    //MARK: - Kullanıcılara Bildirim Gönderme
    // Bildirim gönderecek olan fonksiyon
        func sendNotificationsToUsers() {
            let emailService = EmailService()
            // E-posta gönderme işlemini başlat
            emailService.sendCategoryBasedNotifications()
            emailService.sendEventReminderEmails()
        }
    
    //MARK: - Etkinlikleri Firebase'den Alma
    func fetchEventsFromFirebase() {
        let db = Firestore.firestore()
        
        
        
        db.collection("Events").getDocuments { snapshot, error in
            if let error = error {
                self.makeAlert(title: "Error", message: error.localizedDescription)
                return
            }
            
            guard let snapshot = snapshot else {
                self.makeAlert(title: "Error", message: "No data found.")
                return
            }
            
            self.events.removeAll()
            
            for document in snapshot.documents {
                let documentId = document.documentID
                let data = document.data()
                
                let name = data["name"] as? String ?? ""
                let category = data["category"] as? String ?? ""
                let latitude = data["latitude"] as? Double ?? 0.0
                let longitude = data["longitude"] as? Double ?? 0.0
                let imageUrl = data["imageUrl"] as? String ?? ""
                let place = data["place"] as? String ?? ""
                let url = data["url"] as? String ?? ""
                
                var eventDate: Date?
                if let dateString = data["date"] as? String {
                    // Eğer tarih string olarak kaydedildiyse, bunu Date'ye dönüştür
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                    
                    eventDate = dateFormatter.date(from: dateString)
                }
                
                // Eğer tarih eksikse ya da dönüştürülemiyorsa, varsayılan bir tarih belirleyin
                let date = eventDate ?? Date() // Eğer tarih yoksa, bugünün tarihi kullanılır.
                
                // Kategori Türkçeye çevir
                let translatedCategory = self.categoryTranslations[category] ?? category
                

                
                // Event nesnesini oluştur
                let event = Event(id: documentId, name: name, date: date, category: translatedCategory, latitude: latitude, longitude: longitude, imageUrl: imageUrl, place: place, url: url)
                
                // Etkinliği diziye ekle
                self.events.append(event)
            }
            
            // Filtreli etkinlikleri güncelle
            self.filteredEvents = self.events
            
            // UI güncelleme
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    //MARK: - Etkinlikleri Kategorileme
    func fetchEventsFilteredByCategory(category: String?) {
        if let category = category {
            filteredEvents = events.filter { $0.category == category }
        } else {
            filteredEvents = events
        }
        tableView.reloadData()
    }
    
    //MARK: - DetailsVC'ye Geçiş
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
            if let navigationController = segue.destination as? UINavigationController,
               let destinationVC = navigationController.topViewController as? DetailsVC {
                if let event = sender as? Event {
                    destinationVC.event = event
                    print("Event passed to DetailsVC: \(String(describing: event.name))")
                }
            }
            
        }
    
    //MARK: - SearchBar Olayı
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredEvents = events
        } else {
            filteredEvents = events.filter { event in
                let nameContains = event.name?.lowercased().contains(searchText.lowercased())
                return nameContains!
            }
        }
        tableView.reloadData()
    }

    //MARK: - Uyarı Ekranı
    func makeAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        present(alert, animated: true)
    }
    
    //MARK: - Kullanıcı Adı Ve Fotosu Alma
    func fetchUserDataAndDisplay() {
        // Firestore referansı
        let db = Firestore.firestore()

        // Mevcut kullanıcıyı kontrol edin
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Kullanıcı oturum açmamış.")
            return
        }

        // Kullanıcıya ait veriyi alın
        db.collection("UserInfo").document(userId).getDocument { (document, error) in
            if let error = error {
                print("Kullanıcı verisi alınamadı: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                // Kullanıcı adı ve resim URL'si
                let userName = document.data()?["name"] as? String ?? "Kullanıcı"
                let imageUrl = document.data()?["profilePictureURL"] as? String ?? ""

                // UILabel'e kullanıcı adını yazdır
                self.hiLabel.text = "Merhaba, \(userName)"

                // UIImageView'da resmi göster
                if let url = URL(string: imageUrl) {
                    self.profileImageView.sd_setImage(with: url, placeholderImage: UIImage(named: "unkonown"))
                }
            } else {
                print("Kullanıcı belgesi bulunamadı.")
            }
        }
    }
}

//MARK: - UITableViewDelegate, UITableViewDataSource
extension HomepageVC: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 300
    }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 30 // Bölümler arası boşluk eklemek için
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20 // Başlık eklemek istemiyorsanız sıfır yapabilirsiniz
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedEvent = filteredEvents[indexPath.row]
        performSegue(withIdentifier: "showEventDetails", sender: selectedEvent)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredEvents.count
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.contentView.frame = cell.contentView.frame.inset(by: UIEdgeInsets(top: 5, left: 5, bottom: 5, right: 5))
        cell.layer.shadowPath = UIBezierPath(roundedRect: cell.contentView.frame, cornerRadius: 15).cgPath
        cell.layer.masksToBounds = false // Gölgenin görünmesini sağlar
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath) as? EventCell else {
                fatalError("EventCell not found")
            }
            
            cell.contentView.layer.cornerRadius = 15
            cell.contentView.layer.masksToBounds = true // Sadece içerik için köşeler yuvarlanır

            // Gölgeleri sadece cell'e değil, contentView dışında yapıyoruz.
            cell.layer.shadowColor = UIColor.black.cgColor
            cell.layer.shadowOpacity = 0.3
            cell.layer.shadowOffset = CGSize(width: 0, height: 4)
            cell.layer.shadowRadius = 6
            cell.layer.masksToBounds = false // Gölge görünebilmesi için false

            // Hücre gölgesinin sınırlarını belirleyin
            cell.layer.shadowPath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 15).cgPath
        cell.visualEffect.layer.cornerRadius = 10
        
        let event = filteredEvents[indexPath.row]
        cell.nameLabel.text = event.name
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "tr_TR") // Türkçe format için
        // Tarih için format
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let formattedDate = dateFormatter.string(from: event.date ?? Date())

        // Saat için format
        dateFormatter.dateFormat = "HH:mm"
        let formattedTime = dateFormatter.string(from: event.date ?? Date())

        // Ayrı label'lara yazdır
        cell.dateLabel.text = formattedDate
        cell.timeLabel.text = formattedTime
        cell.placeLabel.text = event.place
        if let imageUrl = URL(string: event.imageUrl ?? "") {
            cell.imageview.sd_setImage(with: imageUrl, placeholderImage: UIImage(named: "placeholder"))
        }
        
        
        
        return cell
    }
}

//MARK: - Konum Bilgisi Alma
extension HomepageVC {
    func getCityAndCountry(from location: CLLocation) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            guard let placemark = placemarks?.first, error == nil else {
                print("Ters geocode işlemi sırasında hata: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                return
            }
            
            // Şehir ve ülke bilgilerini alın
            let city = placemark.locality ?? "Bilinmeyen Şehir"
            let country = placemark.country ?? "Bilinmeyen Ülke"
            
            // Label'ı güncelleyin
            DispatchQueue.main.async {
                self.locationLabel.text = "\(city), \(country)"
            }
        }
    }
}

//MARK: - Özelleştirilmiş Görsel Fonksiyonu
extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        self.draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}

//MARK: - Özelleştirilmiş Renk Fonksiyonu
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let g = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
