//
//  EmailService.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 2.01.2025.
//

import Alamofire
import FirebaseFirestore
class EmailService {
    
    // SendGrid API ile e-posta gönderme fonksiyonu
    func sendEmail(to recipient: String, subject: String, content: String) {
        let url = "https://api.sendgrid.com/v3/mail/send"
        
        let parameters: [String: Any] = [
            "personalizations": [
                [
                    "to": [
                        ["email": recipient]
                    ],
                    "subject": subject
                ]
            ],
            "from": [
                "email": "rumeysatokur_1999@hotmail.com"
            ],
            "content": [
                [
                    "type": "text/plain",
                    "value": content
                ]
            ]
        ]
        
        let headers: HTTPHeaders = [
            "Authorization": "Bearer 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",
            "Content-Type": "application/json"
        ]
        
        AF.request(url, method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .response { response in
                switch response.result {
                case .success:
                    print("Email sent successfully!")
                case .failure(let error):
                    print("Error sending email: \(error)")
                    print("Response: \(response)")
                }
            }
    }
    // Firebase'den favorilerdeki etkinlikleri kontrol et ve yeni etkinlikleri karşılaştır
    func sendCategoryBasedNotifications() {
        let db = Firestore.firestore()
        
        // "UserInfo" koleksiyonundan tüm kullanıcıları al
        db.collection("UserInfo").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting documents: \(error)")
                return
            }
            
            for document in snapshot!.documents {
                let userId = document.documentID
                let userEmail = document["email"] as? String ?? ""
                
                // Kullanıcının notifications mapindeki general alanını kontrol et
                if let notifications = document["notifications"] as? [String: Bool],
                   let generalNotificationEnabled = notifications["general"], generalNotificationEnabled {
                    
                    // Kullanıcının favorites alt koleksiyonunu al
                    db.collection("UserInfo").document(userId).collection("favorites").getDocuments { favoritesSnapshot, error in
                        if let error = error {
                            print("Favorites koleksiyonunu alırken hata oluştu: \(error)")
                            return
                        }
                        
                        guard let favoritesDocuments = favoritesSnapshot?.documents, !favoritesDocuments.isEmpty else {
                            print("Kullanıcının favorileri yok veya boş: \(userId)")
                            return
                        }
                        
                        for favoriteDocument in favoritesDocuments {
                            if let eventId = favoriteDocument["eventId"] as? String {
                                // Favori etkinliğin kategorisini al
                                db.collection("Events").document(eventId).getDocument { eventSnapshot, error in
                                    if let error = error {
                                        print("Error getting event document: \(error)")
                                        return
                                    }
                                    
                                    if let eventSnapshot = eventSnapshot, eventSnapshot.exists {
                                        let favoriteEventCategory = eventSnapshot["category"] as? String ?? ""
                                        
                                        // Yeni etkinliklerin kategorisini kontrol et
                                        self.checkForNewEvents(userId: userId, favoriteCategory: favoriteEventCategory, userEmail: userEmail)
                                    }
                                }
                            } else {
                                print("Favori belgesinde eventId alanı eksik: \(favoriteDocument.documentID)")
                            }
                        }
                    }
                } else {
                    print("Kullanıcının genel bildirimleri açık değil: \(userId)")
                }
            }
        }
    }
    
    // Yeni etkinlikleri kontrol et ve kategori eşleşirse bildirim gönder
    func checkForNewEvents(userId: String, favoriteCategory: String, userEmail: String) {
        let db = Firestore.firestore()
        let currentDate = Date()

        // Yeni etkinlikleri, güncel tarihten sonra başlayacak şekilde al ve kategoriye göre filtrele
        db.collection("Events")
            .whereField("category", isEqualTo: favoriteCategory)
            .whereField("date", isGreaterThan: ISO8601DateFormatter().string(from: currentDate)) // Tarih filtresi
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting new events: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("Yeni etkinlik bulunamadı.")
                    return
                }
                
                // Yalnızca ilk 3 etkinliği alın
                let limitedDocuments = documents.prefix(2)
                
                let dateFormatter = DateFormatter()
                dateFormatter.locale = Locale(identifier: "tr_TR")
                dateFormatter.dateStyle = .long
                dateFormatter.timeStyle = .short
                
                // Yeni etkinlik bulunduğunda bildirim gönder
                for document in limitedDocuments {
                    let eventName = document["name"] as? String ?? "Bilinmeyen Etkinlik"
                    let eventPlace = document["place"] as? String ?? "Bilinmeyen Yer"
                    let eventDateString = document["date"] as? String ?? ""
                    
                    // Tarihi formatla
                    let eventDate: String
                    if let date = ISO8601DateFormatter().date(from: eventDateString) {
                        eventDate = dateFormatter.string(from: date)
                    } else {
                        eventDate = "Tarih bilinmiyor"
                    }
                    // İngilizce-Türkçe kategori çevirisi
                    // Kategori çeviri sözlüğü
                    let categoryTranslations: [String: String] = [
                        "Music": "Müzik",
                        "Sports": "Spor",
                        "Arts & Theatre": "Sanat ve Tiyatro",
                        "Festivals": "Festivaller"
                    ]
                    // Türkçe kategori adı
                    let translatedCategory = categoryTranslations[favoriteCategory] ?? favoriteCategory
                    // Bildirim içeriği
                    let subject = "Beğenebileceğiniz Yeni \(translatedCategory) Etkinliği!"
                    let content = """
                    Sayın LEDA kullanıcısı,
                    
                    \(eventDate) tarihinde \(eventPlace) adresinde '\(eventName)' başlıklı yeni bir \(favoriteCategory) etkinliği gerçekleşiyor. Buna bir bak!
                    """
                    
                    // E-posta gönder
                    self.sendEmail(to: userEmail, subject: subject, content: content)
                }
            }
    }

    // Firebase'den katılımcıların etkinliklerini al ve bildirim gönder
    func sendEventReminderEmails() {
        let db = Firestore.firestore()
        
        // "participations" koleksiyonundan verileri al
        db.collection("Participations").getDocuments { snapshot, error in
            if let error = error {
                print("Error getting documents: \(error)")
                return
            }
            guard let documents = snapshot?.documents else {
                print("No participation documents found.")
                return
            }
            for document in documents  {
                guard let eventId = document["eventId"] as? String, let userId = document["userId"] as? String else {
                    print("Invalid data in participation document.")
                    continue
                }
                
                // Etkinlik verilerini al
                db.collection("Events").document(eventId).getDocument { eventSnapshot, error in
                    if let error = error {
                        print("Error getting event document: \(error)")
                        return
                    }
                    
                    guard let eventSnapshot = eventSnapshot, eventSnapshot.exists,
                          let eventName = eventSnapshot["name"] as? String,
                          let eventDate = eventSnapshot["date"] as? String,
                          let eventPlace = eventSnapshot["place"] as? String else {
                        print("Event data is incomplete for event ID: \(eventId)")
                        return
                    }
                    
                    // Kullanıcı bilgilerini al
                    db.collection("UserInfo").document(userId).getDocument { userSnapshot, error in
                        if let error = error {
                            print("Error getting user document: \(error)")
                            return
                        }
                        
                        guard let userSnapshot = userSnapshot, userSnapshot.exists,
                              let userEmail = userSnapshot["email"] as? String,
                              let userName = userSnapshot["name"] as? String,
                              let eventUpdates = userSnapshot["notifications.eventUpdates"] as? Bool else {
                            print("User data is incomplete for user ID: \(userId)")
                            return
                        }
                        
                        // Kullanıcının etkinlik güncellemeleri almak istediğinden emin ol
                        if eventUpdates {
                            let dateFormatter = ISO8601DateFormatter()
                            if let eventDateParsed = dateFormatter.date(from: eventDate) {
                                
                                // Hatırlatma göndermek için gereken zamanı hesapla (örneğin etkinlikten 1 gün önce)
                                let reminderTime = eventDateParsed.addingTimeInterval(-86400) // 1 gün önce
                                
                                let currentDate = Date()
                                
                                if currentDate >= reminderTime {
                                    let subject = "Hatırlatma: Yaklaşan Etkinlik - \(eventName)"
                                    // Tarihi okunabilir bir formata dönüştürme
                                    let dateFormatter = DateFormatter()
                                    dateFormatter.locale = Locale(identifier: "tr_TR") // Türkçe yerel ayar
                                    dateFormatter.dateFormat = "d MMMM yyyy, HH:mm" // Örnek: 4 Ocak 2025, 19:15
                                        
                                    let formattedEventDate = dateFormatter.string(from: eventDateParsed) // `eventDateParsed` ISO8601 formatındaki tarih
                                    let content = """
                                                Sayın \(userName),
                                                
                                                Bu \(formattedEventDate) tarihinde \(eventPlace)'de gerçekleşecek olan \(eventName) etkinliği için bir hatırlatmadır. Kaçırmayın!
                                                """
                                    self.sendEmail(to: userEmail, subject: subject, content: content)
                                }
                            } else {
                                print("Invalid date format for event ID: \(eventId)")
                            }
                        }
                    }
                }
            }
        }
    }
}
    
    

