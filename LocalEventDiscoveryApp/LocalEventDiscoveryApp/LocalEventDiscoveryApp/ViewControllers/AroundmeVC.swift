//
//  AroundmeVC.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 16.11.2024.
//

import UIKit
import GoogleMaps
import CoreLocation
import FirebaseFirestore

class AroundmeVC: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {

    var mapView: GMSMapView!
    let locationManager = CLLocationManager()
    var events: [GMSMarker: [String: Any]] = [:] // Marker ile veri eşleştirme
    
    // MARK: - View Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Haritayı başlat
        setupMapView()
        
        // Konum butonunu ekle
        setupLocationButton()
        
        // Firebase'den etkinlikleri al
        fetchEventsFromFirestore()
        
        // Kullanıcının konumunu al
        startLocationUpdates()
    }
    
    // MARK: - SetupMapView
    func setupMapView() {
        // Haritayı başlat (Varsayılan konum ile)
        let initialCamera = GMSCameraPosition.camera(withLatitude: 39.9061, longitude: 41.2649, zoom: 6.0)
        // MapView boyutunu ayarla
        let mapFrame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 809)
        mapView = GMSMapView.map(withFrame: mapFrame, camera: initialCamera)
        mapView.delegate = self
        self.view.addSubview(mapView)
    }
    
    // MARK: - Konum Butonu Ayarla
    func setupLocationButton() {
        let locationButton = UIButton(frame: CGRect(x: view.frame.width - 70, y: 70, width: 50, height: 50))
        locationButton.backgroundColor = .white
        locationButton.layer.cornerRadius = 25
        locationButton.setImage(UIImage(systemName: "location.fill"), for: .normal)
        locationButton.tintColor = .systemBlue
        locationButton.addTarget(self, action: #selector(centerUserLocation), for: .touchUpInside)
        self.view.addSubview(locationButton)
    }
    
    //MARK: - Firebase'den Etkinlikleri Çekme
    func fetchEventsFromFirestore() {
        let db = Firestore.firestore()
        
        db.collection("Events").getDocuments { (snapshot, error) in
            if let error = error {
                print("Etkinlikleri alırken hata oluştu: \(error)")
                return
            }
            
            guard let documents = snapshot?.documents else { return }
            
            for document in documents {
                let data = document.data()
                if let name = data["name"] as? String,
                   let place = data["place"] as? String,
                   let date = data["date"] as? String,
                   let latitude = data["latitude"] as? Double,
                   let longitude = data["longitude"] as? Double {
                    
                    let marker = GMSMarker()
                    marker.position = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    marker.title = name
                    marker.icon = UIImage(named: "marker") // Özel görsel
                    marker.map = self.mapView
                    
                    // Marker ile veriyi eşleştir
                    self.events[marker] = ["name": name, "place": place, "date": date, "latitude": latitude, "longitude": longitude]
                }
            }
        }
    }

    
    // MARK: - Location Methods
    @objc func centerUserLocation() {
        if let location = locationManager.location?.coordinate {
            mapView.animate(to: GMSCameraPosition.camera(withTarget: location, zoom: 12.0))
        }
    }

    // MARK: -Kullanıcı Konumu Güncelleme
    func startLocationUpdates() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }

    // MARK: - Map View Delegate Methods
    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        if let eventData = events[marker] {
            guard let name = eventData["name"] as? String,
                  let place = eventData["place"] as? String,
                  let dateString = eventData["date"] as? String,
                  let latitude = eventData["latitude"] as? Double,
                  let longitude = eventData["longitude"] as? Double else {
                print("Veriler eksik.")
                return true
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "tr_TR")
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
            
            let formattedDate: String
            if let eventDate = dateFormatter.date(from: dateString) {
                dateFormatter.dateFormat = "dd MMMM yyyy, HH:mm"
                formattedDate = dateFormatter.string(from: eventDate)
            } else {
                formattedDate = "Tarih formatı hatalı"
                print("Tarih formatı doğru değil: \(dateString)")
            }
            
            let alertController = UIAlertController(
                title: name,
                message: "Yer: \(place)\nTarih: \(formattedDate)",
                preferredStyle: .alert
            )
            
            alertController.addAction(UIAlertAction(title: "Yön Tarifi Al", style: .default, handler: { _ in
                self.openDirections(latitude: latitude, longitude: longitude)
            }))
            
            alertController.addAction(UIAlertAction(title: "İptal", style: .cancel, handler: nil))
            
            self.present(alertController, animated: true, completion: nil)
        } else {
            print("Marker'a ait veri bulunamadı.")
        }
        return true
    }
    
    // MARK: - Directions Methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            let userLocation = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            mapView.animate(to: GMSCameraPosition.camera(withTarget: userLocation, zoom: 12.0))
            locationManager.stopUpdatingLocation()
        }
    }
    
    //MARK: - Yol Tarifi Al
    func openDirections(latitude: Double, longitude: Double) {
        let googleMapsURL = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"
        if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
            if let url = URL(string: googleMapsURL) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
    }
}
