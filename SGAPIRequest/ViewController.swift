//
//  ViewController.swift
//  SGAPIRequest
//
//  Created by 王伟屹 on 2018/1/17.
//  Copyright © 2018年 siegrain. All rights reserved.
//

import UIKit
import PromiseKit

class ViewController: UIViewController {

    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func buttonDidPress(_ sender: Any) {
        // 字典
//        firstly { () -> Promise<[String: Any]> in
//            return CallApi(ZhihuAPI.latest)
//        }.then { [weak self] (result) -> Void in
//            self?.textView.text = "\(result)"
//        }
        
        // 模型
//        firstly { () -> Promise<LatestStoriesModel> in
//            return CallApi(ZhihuAPI.latest)
//        }.then { [weak self] (result) -> Void in
//            self?.textView.text = "\(result.toJSONString()!)"
//        }
        
        // 缓存
        firstly { () -> Promise<[String: Any]> in
            return CallApi(ZhihuAPI.latest, isCached: true)
        }.then { [weak self] (result) -> Void in
            self?.textView.text = "\(result)"
        }
    }
}
