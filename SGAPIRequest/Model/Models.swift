//
//  Models.swift
//  SGAPIRequest
//
//  Created by 王伟屹 on 2018/1/17.
//  Copyright © 2018年 siegrain. All rights reserved.
//

import Foundation
import HandyJSON

struct StoryModel: HandyJSON {
    var id: Int!
    var title: String!
    var images: [String]?
    var image: String?
}

struct LatestStoriesModel: HandyJSON {
    var date: String!
    var stories: [StoryModel]?
    var top_stories: [StoryModel]?
}
