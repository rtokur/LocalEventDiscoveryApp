//
//  CommentsVC.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 2.12.2024.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
class CommentsVC: UIViewController,UITableViewDelegate,UITableViewDataSource,UITextViewDelegate {
    // MARK: - Properties
    var eventId :String = ""
    var comments: [Comment] = []
    
    // MARK: - IBOutlets
    @IBOutlet weak var commentTextView: UITextView!
    @IBOutlet weak var addComentButton: UIButton!
    @IBOutlet weak var commentTableView: UITableView!
    
    // MARK: - IBActions
    @IBAction func AddCommentButton(_ sender: Any) {
        if let comment = commentTextView.text, !comment.isEmpty {
            let userId = Auth.auth().currentUser?.uid ?? "unknown_user"
            saveComment(eventID: eventId, userID: userId, comment: comment)
            commentTextView.text = ""
        } else {
            self.makeAlert(title: "Boş", message: "Lütfen yorum yazınız.")
        }
    }
    // MARK: - UITableView DataSource & Delegate Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "CommentsCell", for: indexPath) as? CommentsCell else {
            fatalError("CommentsCell bulunamadı veya yanlış bir türde.")
        }

        let comment = comments[indexPath.row]
        cell.commentLabel.text = comment.comment
        cell.userNameLabel.text = comment.userName
        cell.likeCountLabel.text = "\(comment.likes) Beğeni"
        cell.onLikeButtonTapped = { [weak self] in
            self?.likeComment(commentID: comment.commentID)
        }
        // Kullanıcı görselini yükle
        if let url = URL(string: comment.userImageURL) {
            DispatchQueue.global().async {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        cell.profileImageView.image = image
                    }
                } else {
                    DispatchQueue.main.async {
                        cell.profileImageView.image = UIImage(named: "unkonown") // Varsayılan görsel
                    }
                }
            }
        } else {
            cell.profileImageView.image = UIImage(named: "unkonown") // Varsayılan görsel
        }
        // Zamanı hesaplayıp göster
        cell.timeLabel.text = timeAgoDisplay(from: comment.timestamp)
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    // MARK: - Comment Model
    struct Comment {
        var commentID : String
        var userName: String
        var comment: String
        var userID:String
        var userImageURL:String
        var timestamp: Date
        var likes:Int
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        commentTableView.delegate = self
        commentTableView.dataSource = self
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        // Yorumları yükle
        loadComments()
        addComentButton.layer.cornerRadius = 15
        let colors: [UIColor] = [.systemPurple,.blue]
        addComentButton.setGradientBackground(colors: colors)
        commentTextView.delegate = self
        commentTextView.isScrollEnabled = false // Dinamik boy için kaydırmayı kapatın
        commentTextView.layer.cornerRadius = 15
        commentTextView.layer.borderWidth = 1
        commentTextView.layer.borderColor = UIColor(hex: "#c054b3").cgColor
        
    }
    
    //MARK: -Klavye Kapatma
    @objc func dismissKeyboard() {
        view.endEditing(true) // Klavyeyi kapatır
    }
    
    // MARK: - UITextView Delegate Methods
    func textViewDidChange(_ textView: UITextView) {
        // İçerik boyutuna göre dinamik yükseklik ayarı
        let size = CGSize(width: textView.frame.width, height: .infinity)
        let estimatedSize = textView.sizeThatFits(size)
        textView.constraints.forEach { constraint in
            if constraint.firstAttribute == .height {
                constraint.constant = estimatedSize.height
            }
        }
    }
    
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Yorumunuzu buraya yazın..." {
            textView.text = ""
            textView.textColor = .black
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Yorumunuzu buraya yazın..."
            textView.textColor = .lightGray
        }
    }
    
    // MARK: - Comment Interaction Methods
    func likeComment(commentID: String) {
        let db = Firestore.firestore()
        let commentRef = db.collection("Events").document(eventId).collection("Comments").document(commentID)

        guard let userID = Auth.auth().currentUser?.uid else { return }

        commentRef.getDocument { (document, error) in
            if let document = document, document.exists {
                var likedBy = document.get("likedBy") as? [String] ?? []
                var currentLikes = document.get("likes") as? Int ?? 0

                if likedBy.contains(userID) {
                    // Kullanıcı zaten beğenmiş, geri al
                    likedBy.removeAll { $0 == userID }
                    currentLikes -= 1
                } else {
                    // Kullanıcı beğeniyor
                    likedBy.append(userID)
                    currentLikes += 1
                }

                // Firestore'da güncelleme yap
                commentRef.updateData([
                    "likes": currentLikes,
                    "likedBy": likedBy
                ]) { error in
                    if let error = error {
                        print("Beğeni güncellenirken hata: \(error.localizedDescription)")
                    } else {
                        self.loadComments() // Tabloyu yenile
                    }
                }
            } else {
                print("Yorum bulunamadı: \(error?.localizedDescription ?? "Bilinmeyen hata")")
            }
        }
    }

    func timeAgoDisplay(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR") // Türkçe dili ayarı
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // MARK: - Load & Save Comments
    func loadComments() {
        let db = Firestore.firestore()
        let commentsRef = db.collection("Events").document(eventId).collection("Comments")

        commentsRef.order(by: "timestamp", descending: false).getDocuments { querySnapshot, error in
            if let error = error {
                print("Yorumlar alınırken hata oluştu: \(error.localizedDescription)")
            } else {
                self.comments = []
                let group = DispatchGroup()

                querySnapshot?.documents.forEach { document in
                    let data = document.data()
                    let commentID = document.documentID // Yorumun benzersiz ID'si
                    let userID = data["userID"] as? String ?? "Bilinmeyen Kullanıcı"
                    let commentTextView = data["comment"] as? String ?? ""
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date() // Firestore timestamp
                    let likes = data["likes"] as? Int ?? 0 // Beğeni sayısı
                        
                    group.enter()

                    db.collection("UserInfo").document(userID).getDocument { userDoc, error in
                        if let userData = userDoc?.data() {
                            let name = userData["name"] as? String ?? "Ad yok"
                            let profileImageURL = userData["profilePictureURL"] as? String ?? ""

                            let comment = Comment(commentID: commentID, userName: name, comment: commentTextView, userID: userID, userImageURL: profileImageURL,timestamp: timestamp,likes: likes)
                                self.comments.append(comment)
                        } else {
                            print("Kullanıcı bilgileri alınamadı: \(error?.localizedDescription ?? "Bilinmeyen hata")")
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.commentTableView.reloadData()
                }
            }
        }
    }

    // MARK: -Save Comment
    func saveComment(eventID: String, userID: String, comment: String) {
        let db = Firestore.firestore()
        let eventRef = db.collection("Events").document(eventID)
        let commentsRef = eventRef.collection("Comments")

        commentsRef.addDocument(data: [
            "userID": userID,
            "comment": comment,
            "timestamp": FieldValue.serverTimestamp()
        ]) { error in
            if let error = error {
                print("Yorum kaydedilirken hata oluştu: \(error.localizedDescription)")
            } else {
                self.makeAlert(title: "Başarılı", message: "Yorumunuz eklendi.")
                self.loadComments()
            }
        }
    }
    
    // MARK: - Helper Methods
    func makeAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okButton = UIAlertAction(title: "OK", style: .default)
        alert.addAction(okButton)
        present(alert, animated: true)
    }
}

