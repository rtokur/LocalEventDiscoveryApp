//
//  JoinedEventCell.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 3.12.2024.
//

import UIKit

class JoinedEventCell: UITableViewCell {
    
    // MARK: - IBOutlets
    @IBOutlet weak var jEventNameLabel: UILabel!
    @IBOutlet weak var eventImageView: UIImageView!
    @IBOutlet weak var dateImageView: UIImageView!
    @IBOutlet weak var jEventDateLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

}
