//
//  Item.swift
//  MiaoJiAccout
//
//  Created by 清眸 on 2026/6/9.
//

import Foundation

struct Item: Identifiable {
    let id = UUID()
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
