//
//  CommentsCell.swift
//  LocalEventDiscoveryApp
//
//  Created by Rumeysa Tokur on 2.12.2024.
//

import UIKit

class CommentsCell: UITableViewCell {
    // MARK: - Properties
    var onLikeButtonTapped: (() -> Void)?
    
    // MARK: - IBOutlets
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var likeButton: UIButton!
    @IBOutlet weak var likeCountLabel: UILabel!
    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var commentLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    // MARK: - IBActions
    @IBAction func likeButton(_ sender: UIButton) {
        // Beğeni animasyonu
        animateLikeButton()
        onLikeButtonTapped?()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        profileImageView.layer.cornerRadius = profileImageView.frame.size.width / 2
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    private func animateLikeButton() {
        UIView.animate(withDuration: 0.2, animations: {
            self.likeButton.transform = CGAffineTransform(scaleX: 1.2, y: 1.2) // Biraz büyüt
        }, completion: { _ in
            UIView.animate(withDuration: 0.2) {
                self.likeButton.transform = CGAffineTransform.identity // Orijinal boyuta dön
            }})
    }

}
