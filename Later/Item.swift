//
//  Item.swift
//  Later
//
//  Created by Akshay Shukla on 03/06/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
