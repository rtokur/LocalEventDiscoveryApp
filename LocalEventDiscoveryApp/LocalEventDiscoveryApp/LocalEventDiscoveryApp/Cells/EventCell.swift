//
//  EventsCell.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 18.11.2024.
//

import UIKit

class EventCell: UITableViewCell {

    // MARK: - IBOutlets
    @IBOutlet weak var visualEffect: UIVisualEffectView!
    @IBOutlet weak var imageview: UIImageView!
    @IBOutlet weak var dateLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var placeLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
