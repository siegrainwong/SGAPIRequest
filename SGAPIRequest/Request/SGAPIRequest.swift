//
//  SGAPIRequest.swift
//  SGAPIRequest
//
//  Created by 王伟屹 on 2018/1/17.
//  Copyright © 2018年 siegrain. All rights reserved.
//

import PromiseKit
import Moya
import HandyJSON
import AwesomeCache

private let globalCache = try! Cache<NSString>(name: "globalCache")
private let cacheExpireDate = CacheExpiry.seconds(60*60*24)

/// 调用接口，成功返回字典
///
/// - Parameter target:
/// - Returns:
func CallApi(_ target: ZhihuAPI, isCached: Bool = false) -> Promise<[String : Any]> {
    
    let cacheKey = "dictionary:" + target.path
    
    // 优先获取缓存
    if isCached, let jsonString = globalCache[cacheKey] {
        return Promise<[String : Any]> { fulfill, reject in
            do {
                let data = try JSONSerialization.jsonObject(with: jsonString.data(using: String.Encoding.utf8.rawValue)!, options: []) as? [String: Any]
                
                print("fetch from cache")
                fulfill(data!)
            } catch {
                reject(error)
            }
        }
    }
    
    let provider = MoyaProvider<ZhihuAPI>()
    
    return Promise<[String : Any]> { fulfill, reject in
        provider.request(target, completion: { (result) in
            switch result {
            case let .success(response):
                do {
                    // 缓存
                    try globalCache.setObject(response.mapString() as NSString, forKey: cacheKey, expires: cacheExpireDate)
                    
                    print("fetch from request")
                    let data = try JSONSerialization.jsonObject(with: response.data, options: []) as! [String: Any]
                    fulfill(data)
                } catch {
                    reject(error)
                }
            case let .failure(error):
                reject(error)
            }
        })
    }
}

/// 调用接口，成功返回模型数组
///
/// - Parameter target:
/// - Returns:
func CallApi<T: HandyJSON>(_ target: ZhihuAPI) -> Promise<[T?]?> {
    
    let provider = MoyaProvider<ZhihuAPI>()
    
    return Promise<[T?]?> { fulfill, reject in
        provider.request(target, completion: { (result) in
            switch result {
            case let .success(response):
                do {
                    let data = try [T].deserialize(from: response.mapString())
                    fulfill(data)
                } catch {
                    reject(error)
                }
            case let .failure(error):
                reject(error)
            }
        })
    }
}


/// 调用接口，成功返回模型
///
/// - Parameter target:
/// - Returns:
func CallApi<T: HandyJSON>(_ target: ZhihuAPI) -> Promise<T> {
    
    let provider = MoyaProvider<ZhihuAPI>()
    
    return Promise<T> { fulfill, reject in
        provider.request(target, completion: { (result) in
            switch result {
            case let .success(response):
                do {
                    let data = try T.deserialize(from: response.mapString())
                    fulfill(data!)
                } catch {
                    reject(error)
                }
            case let .failure(error):
                reject(error)
            }
        })
    }
}

