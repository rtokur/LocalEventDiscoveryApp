import UIKit
import Firebase
import FirebaseAuth
import GoogleSignIn
import GoogleSignInSwift
import FirebaseStorage

class SignInVC: UIViewController {
    
    // MARK: - Authentication Errors
    enum AuthenticationError: Error {
        case tokenError(message: String)
        case missingClientID
        case noRootViewController
        case unknown(message: String)
    }
    
    // MARK: - Properties
    var counter = 0
    private var errorMessage: String?
    var isSignInMode = true
    // MARK: - Outlets
    @IBOutlet weak var backButtonClicked: UIButton!
    @IBOutlet weak var signInWithGoogle: UIButton!
    @IBOutlet weak var orLabel: UILabel!
    @IBOutlet weak var signInClicked: UIButton!
    @IBOutlet weak var continueLabel: UILabel!
    @IBOutlet weak var enterNameLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var nameText: UITextField!
    @IBOutlet weak var enterPhoneLabel: UILabel!
    @IBOutlet weak var emailText: UITextField!
    @IBOutlet weak var phoneText: UITextField!
    @IBOutlet weak var nameImageView: UIImageView!
    @IBOutlet weak var phoneImageView: UIImageView!
    @IBOutlet weak var haveAccountLabel: UILabel!
    @IBOutlet weak var passwordText: UITextField!
    @IBOutlet weak var changePassword: UIButton!
    @IBOutlet weak var signUpClicked: UIButton!
    
    // MARK: - Actions
    @IBAction func backButtonClicked(_ sender: Any) {
        configureForSignInMode()
    }
    
    @IBAction func signInClicked(_ sender: Any) {
        isSignInMode = true
        configureForSignInMode()
        if passwordText.text != "" && emailText.text != "" {
            Auth.auth().signIn(withEmail: emailText.text!, password: passwordText.text!) { result, error in
                if error != nil {
                    self.makeAlert(title: "Hata", message: error?.localizedDescription ?? "Hata")
                } else {
                    self.performSegue(withIdentifier: "toHomepageVC", sender: nil)
                }
            }
        } else {
            self.makeAlert(title: "Error", message: "Şifre/Email ?")
        }
    }
    
    @IBAction func signUpClicked(_ sender: UIButton) {
        isSignInMode = false
        
        UIView.animate(withDuration: 0.3) { // Hareketi yumuşatmak için animasyon
            sender.frame.origin = CGPoint(x: 140, y: 638)
            sender.configuration?.cornerStyle = .capsule
            sender.configuration?.baseForegroundColor = .black
            sender.backgroundColor = .white
            sender.layer.cornerRadius = 25
        }
        
        if counter != 0 {
            if passwordText.text != "" && emailText.text != "" && nameText.text != "" && phoneText.text != "" {
                Auth.auth().createUser(withEmail: emailText.text!, password: passwordText.text!) { auth, error in
                    if error != nil {
                        self.makeAlert(title: "Error", message: error?.localizedDescription ?? "Error")
                    } else {
                        guard let userID = Auth.auth().currentUser?.uid else {
                            print("Kullanıcı kimliği alınamadı.")
                            return
                        }
                        let firestore = Firestore.firestore()
                        
                        let userDictionary = ["email" : self.emailText.text!, "name" : self.nameText.text!, "phone" : self.phoneText.text!, "notifications": ["general": false, "eventUpdates": false]] as! [String: Any]
                        let userRef = firestore.collection("UserInfo").document(userID)
                        userRef.setData(userDictionary) { error in
                            if error != nil {
                                self.makeAlert(title: "Error", message: error?.localizedDescription ?? "Error")
                            }
                        }
                        self.performSegue(withIdentifier: "toHomepageVC", sender: nil)
                    }
                }
            } else {
                self.makeAlert(title: "Hata", message: "Şifre/Email ?")
            }
        }
        configureForSignUpMode()
    }
    
    @IBAction func changePassword(_ sender: Any) {
        guard let email = emailText.text, !email.isEmpty else {
            self.makeAlert(title: "Hata", message: "Lütfen geçerli bir e-posta adresi girin.")
            return
        }
        sendPasswordReset(email: email)
    }
    
    @IBAction func signInWithGoogle(_ sender: Any) {
        Task {
            let success = await signInWithGoogle()
            if success {
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "toHomepageVC", sender: nil)
                }
            } else {
                print("Giriş başarısız")
            }
        }
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureForSignInMode()
        
        // Stil ayarlarını yapmak için çağır
        styleTextFields()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
        
    }
    
    // MARK: - Helper Methods

    private func styleTextFields() {
        // Styling for image view
        imageView.layer.cornerRadius = 41 // Köşe yarıçapı
        
        // Styling text fields with bottom lines
        addBottomLine(to: emailText)
        addBottomLine(to: passwordText)
        addBottomLine(to: nameText)
        addBottomLine(to: phoneText)
        
        // Set password field to secure entry
        passwordText.isSecureTextEntry = true
    }

    private func addBottomLine(to textField: UITextField) {
        let bottomLine = CALayer()
        bottomLine.frame = CGRect(x: 0, y: textField.frame.height - 1, width: textField.frame.width, height: 1)
        bottomLine.backgroundColor = UIColor.white.cgColor
        textField.layer.addSublayer(bottomLine)
    }
    
    // MARK: - Firestore Methods
    func saveUserToFirestore(_ user: User?) {
        let db = Firestore.firestore()
        
        // Kullanıcı bilgilerini Firestore'a kaydetme
        let userData: [String: Any] = [
            "name": user!.displayName ?? "No name",
            "email": user!.email ?? "No email",
            "profilePictureURL": user!.photoURL?.absoluteString ?? "",
            "phone": user!.phoneNumber ?? "No phone",
            "notifications": ["eventUpdates":false,"general":false,"nearbyEvents":false,"specialOffers":false]
            
        ]
        
        // Kullanıcıyı "users" koleksiyonuna kaydet
        db.collection("UserInfo").document(user!.uid).setData(userData) { error in
            if let error = error {
                print("Kullanıcı bilgileri kaydedilemedi: \(error.localizedDescription)")
            } else {
                print("Kullanıcı bilgileri başarıyla kaydedildi.")
            }
        }
    }
    
    // MARK: - Keyboard Methods
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Sign-In/Sign-Up Configuration Methods
    private func configureForSignInMode() {
        nameText.isHidden = true
        phoneText.isHidden = true
        enterNameLabel.isHidden = true
        enterPhoneLabel.isHidden = true
        nameImageView.isHidden = true
        phoneImageView.isHidden = true
        continueLabel.text = "Devam etmek için giriş yap"
        changePassword.isHidden = false
        signInWithGoogle.isHidden = false
        signInClicked.isHidden = false
        orLabel.isHidden = false
        haveAccountLabel.isHidden = false
        counter = 0
        backButtonClicked.isHidden = true
        UIView.animate(withDuration: 0.3) { // Hareketi yumuşatmak için animasyon
            self.signUpClicked.frame.origin = CGPoint(x: 243, y: 808)
            self.signUpClicked.configuration?.cornerStyle = .fixed
            self.signUpClicked.configuration?.baseForegroundColor = .white
            self.signUpClicked.backgroundColor = .clear
            self.signUpClicked.layer.cornerRadius = 0
        }
    }
    
    private func configureForSignUpMode() {
        nameText.isHidden = false
        phoneText.isHidden = false
        enterNameLabel.isHidden = false
        enterPhoneLabel.isHidden = false
        nameImageView.isHidden = false
        phoneImageView.isHidden = false
        continueLabel.text = "Devam etmek için kaydol"
        changePassword.isHidden = true
        signInWithGoogle.isHidden = true
        signInClicked.isHidden = true
        orLabel.isHidden = true
        haveAccountLabel.isHidden = true
        backButtonClicked.isHidden = false
        guard counter != 0 else{
            counter += 1
            return
        }
    }
    
    // MARK: - Sign In With Google
    func signInWithGoogle() async -> Bool {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            fatalError("No client ID found in Firebase Configuration")
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Çıkış yapmadan önce mevcut kullanıcıdan çıkış yapıyoruz
        GIDSignIn.sharedInstance.signOut()

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("There is no root view controller")
            return false
        }

        do {
            // Yeni bir oturum başlat
            let userAuthentication = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            let user = userAuthentication.user
            guard let idToken = user.idToken else {
                throw AuthenticationError.tokenError(message: "ID token missing")
            }
            let accessToken = user.accessToken
            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString, accessToken: accessToken.tokenString)
            let result = try await Auth.auth().signIn(with: credential)
            let firebaseUser = result.user
            print("User \(firebaseUser.uid) signed in with email \(firebaseUser.email ?? "unknown")")

            // Firestore'a kullanıcı bilgilerini kaydet
            saveUserToFirestore(firebaseUser)

            return true
        } catch {
            print("Hata oluştu: \(error.localizedDescription)")
            switch error {
            case AuthenticationError.tokenError(let message):
                errorMessage = "Token hatası: \(message)"
            default:
                errorMessage = "Oturum açma sırasında bir hata oluştu. Lütfen tekrar deneyin."
            }
        }
        return false
    }

    
    // MARK: - Password Reset Methods
    func sendPasswordReset(email: String) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("Şifre sıfırlama bağlantısı gönderilemedi: \(error.localizedDescription)")
            } else {
                self.makeAlert(title: "Başarılı", message: "Şifre sıfırlama bağlantısı başarıyla gönderildi.")
            }
        }
    }
    
    // MARK: - Alert Methods
    func makeAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
        let okButton = UIAlertAction(title: "Tamam", style: UIAlertAction.Style.default)
        alert.addAction(okButton)
        self.present(alert, animated: true)
    }
}
