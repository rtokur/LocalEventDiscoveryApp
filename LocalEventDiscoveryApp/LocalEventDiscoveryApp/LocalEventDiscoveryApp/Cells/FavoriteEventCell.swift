//
//  FavoriteEventCell.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 3.12.2024.
//

import UIKit

class FavoriteEventCell: UITableViewCell {
    
    // MARK: - IBOutlets
    @IBOutlet weak var eventNameLabel: UILabel!
    @IBOutlet weak var eventDateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
