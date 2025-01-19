//
//  Event.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 17.11.2024.
//

import Foundation

class Event: Decodable {
    var id: String?
    var name: String?
    var date: Date?
    var category: String?
    var latitude: Double?
    var longitude: Double?
    var imageUrl: String?
    var place: String?
    var url: String?
    
    // Custom initializer
    init(id: String?, name: String?, date: Date?, category: String?, latitude: Double?, longitude: Double?, imageUrl: String?, place: String?, url: String?) {
        self.id = id
        self.name = name
        self.date = date
        self.category = category
        self.latitude = latitude
        self.longitude = longitude
        self.imageUrl = imageUrl
        self.place = place
        self.url = url
    }
    
    // Custom date decoding strategy
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case date
        case category
        case latitude
        case longitude
        case imageUrl
        case place
        case url
    }
    
    // Custom date decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try? container.decode(String.self, forKey: .id)
        self.name = try? container.decode(String.self, forKey: .name)
        self.category = try? container.decode(String.self, forKey: .category)
        self.latitude = try? container.decode(Double.self, forKey: .latitude)
        self.longitude = try? container.decode(Double.self, forKey: .longitude)
        self.imageUrl = try? container.decode(String.self, forKey: .imageUrl)
        self.place = try? container.decode(String.self, forKey: .place)
        self.url = try? container.decode(String.self, forKey: .url)

        // Tarih çözümlemesi
        if let dateString = try? container.decode(String.self, forKey: .date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // JSON formatına uygun
            self.date = formatter.date(from: dateString)
        } else {
            self.date = nil // Eksik tarih durumunda nil ata
        }
    }
}
