//
//  ZhihuAPI.swift
//  SGAPIRequest
//
//  Created by 王伟屹 on 2018/1/17.
//  Copyright © 2018年 siegrain. All rights reserved.
//

import Moya

/// 接口
public enum ZhihuAPI {
    /// 最新文章
    case latest
    /// 文章内容
    case content(Int)
}

/// Moya 配置
extension ZhihuAPI: TargetType {
    /// 地址前缀
    public var baseURL: URL { return URL(string: "https://news-at.zhihu.com/api/4")! }
    /// 接口地址
    public var path: String {
        switch self {
        case .latest:
            return "/news/latest"
        case .content(let id):
            return "/news/\(id)"
        }
    }
    /// 请求方法
    public var method: Moya.Method {
        return .get
    }
    /// 参数
    public var task: Task {
        switch self {
        default:
            return .requestPlain
        }
    }
    public var validate: Bool {
        return true
    }
    public var sampleData: Data {
        return "".data(using: String.Encoding.utf8)!
    }
    public var headers: [String: String]? {
        return nil
    }
}
