# 用 Moya + PromiseKit 创建优雅的网络请求层
> 第一次使用`Swift`来做项目，第一步当然就是折腾架构，由于项目时间比较宽裕，使用了较多的时间来进行学习参照，最后使用了这样的架构来作为这个产品的网络层，满足了项目基本的需求，肯定有不少的缺陷，权当各位参考。

先来看看最终我们要达成的目标，下面是一段异步请求接口的代码，这段代码具有**网络请求、序列化及基本的缓存功能**。
```swift
firstly { () -> Promise<[ArticleCategoryModel?]?> in
    return CallApi(DFAPI.navigations, isCache: true)
}.then { [weak self] (data) -> Void in
    self!.navigations = data! 
}
```
这一段请求，由以下4个库实现：
1. [Moya：负责网络请求](https://github.com/Moya/Moya)
2. [PromiseKit：负责干净优雅的链式异步调用](https://github.com/mxcl/PromiseKit)
3. [HandyJSON：负责序列化、反序列化](https://github.com/alibaba/HandyJSON)
4. [AwesomeCache：负责缓存请求结果及缓存过期](https://github.com/aschuch/AwesomeCache)

接下来我们就从这个顺序开始，一步一步配置我们的网络层，首先从最基础的网络请求 `Moya` 开始。
## 1. 用 Moya 构建基础网络请求
基于`Alamofire`的抽象，通过更好的方式管理你的接口及其变量，当你的项目集成`Moya`之后，你的请求会变成这样（代码来源于官方文档）：
```swift
provider = MoyaProvider<GitHub>()
provider.request(.zen) { result in
    switch result {
    case let .success(moyaResponse):
        let data = moyaResponse.data
        let statusCode = moyaResponse.statusCode
        // do something with the response data or statusCode
    case let .failure(error):
        // this means there was a network failure - either the request
        // wasn't sent (connectivity), or no response was received (server
        // timed out).  If the server responds with a 4xx or 5xx error, that
        // will be sent as a ".success"-ful response.
    }
}
```
接下来我们来对`Moya`进行配置。
这里用到了我们熟悉的知乎日报API。
```swift
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
```
### 插件机制
请求接口时，我们往往会需要**验签、请求前菊花跟请求后隐藏菊花**等等功能，这些功能大范围的覆盖了一些接口，在`Moya`中，可以使用插件机制实现这一类的特性。
在`Moya`中，我们使用`MoyaProvider`对象来对接口进行调用，在初始化`MoyaProvider`时，就可以进行插件的配置。
在我的插件中，我配置了验签参数，请求菊花以及错误提示，他大概是这样的（并不用于该演示项目，仅作参考）：
```swift
internal final class SGPreprocessingPlugin: PluginType {
    
    // 在每次请求前调用，获取并拼接验签参数
    func prepare(_ request: URLRequest, target: TargetType) -> URLRequest {
        // 声明并计算各个验签参数...
        ...
        
        // 获取 URL 并拼接
        var req = request
        if var url = req.url?.absoluteString {
            url.append("?nonce=\(nonce)")
            url.append("&timestamp=\(timestamp)")
            url.append("&signature=\(signature)")
            url.append("&key=\(key)")
            req.url = URL(string: url)
        }
        
        // 在 Header 中指定 Content-Type
        req.setValue(Constants.API.ContentType, forHTTPHeaderField: "Content-Type")

        return req
    }
    
    /// 发送请求之前
    func willSend(_ request: RequestType, target: TargetType) {
        UIViewController.topViewController()?.view.makeToastActivity(.center)
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    /// 收到响应之后
    func didReceive(_ result: Result<Response, MoyaError>, target: TargetType) {
        UIViewController.topViewController()?.view.hideAllToasts()
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
    
    /// 对响应结果进行预处理
    public func process(_ result: Result<Response, MoyaError>, target: TargetType) -> Result<Response, MoyaError> {
        switch result {
        case .success(let response):
            // 序列化并进行一系列判断，主要判断接口返回是否成功，成功则返回结果，失败则直接弹出服务器给的错误提示。
        case .failure(let error):
            // 请求失败，弹出对应的错误提示。
        }
    }
}
```
当我这样配置完插件（至少基本我每次参与的接口开发中，都有类似的需求），就可以像`Moya`的官方文档那样，声明一个`Provider`并进行调用了，当然在这个演示项目中，并没有什么好配置插件的地方。

这样`Moya`的部分我们就配置完毕了，接下来开始配置`PromiseKit`

## 2. PromiseKit
`PromiseKit`通过链式语法，完美地解决了异步编程时`Block`对代码优雅的破坏，在认识`PromiseKit`之前，我对`Block`可以说是深恶痛绝。
`PromiseKit`长这样（代码来源于官方文档）：
```swift
UIApplication.shared.isNetworkActivityIndicatorVisible = true

firstly {
    when(URLSession.dataTask(with: url).asImage(), CLLocationManager.promise())
}.then { image, location -> Void in
    self.imageView.image = image;
    self.label.text = "\(location)"
}.always {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
}.catch { error in
    UIAlertView(/*…*/).show()
}
```
干净优雅，多重请求时也不会增加`Block`层级。
那么接下来，如何让`PromiseKit`与`Moya`配合使用？

### 结合 Moya 与 PromiseKit
先来个最基本的，调用接口并返回字典，同时为了方便，我们直接将其定义为全局方法。
```swift
import PromiseKit
import Moya

func CallApi(_ target: ZhihuAPI) -> Promise<[String : Any]> {
    
    let provider = MoyaProvider<ZhihuAPI>()
    
    return Promise<[String : Any]> { fulfill, reject in
        provider.request(target, completion: { (result) in
            switch result {
            case let .success(response):
                do {
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
```
这样就结束了，`PromiseKit`很简单，正确时调用`fulfill`，错误时调用`reject`。
我们来调用一下试试看。
```swift
@IBAction func buttonDidPress(_ sender: Any) {
    firstly { () -> Promise<[String: Any]> in
        return CallApi(ZhihuAPI.latest)
    }.then { [weak self] (result) -> Void in
        self?.textView.text = "\(result)"
    }
}
```
![](http://siegrain.wang/_image/2018-01-17-16-32-45.jpg)
> 需要注意的是，在我们将来扩展这个方法时，`Promise`内部可能会出现很多个条件分支，但无论如何你必须要在`Block`结尾之前调用一次`fullfill`或者`reject`，否则`PromiseKit`的`Block`可能会被提前释放掉。

接下来就是拓展这个方法，使其支持反序列化的功能，在请求接口的同时，将我们需要的模型返回过来，这时候就要用到`HandyJSON`了。
当然序列化的工具很多，喜欢什么用什么。

## 3. 用`HandyJSON`让接口调用支持反序列化
这个不做介绍，直接上代码。
```swift
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
```
两个方法分别是用来返回模型跟模型数组的。

这样，我们有了三种返回类型（模型、字典、数组），基本涵盖了所有情况，接下来测试一下。

首先编写模型：
```swift
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

```

然后测试：
```swift
// 模型
firstly { () -> Promise<LatestStoriesModel> in
    return CallApi(ZhihuAPI.latest)
}.then { [weak self] (result) -> Void in
    self?.textView.text = "\(result.toJSONString()!)"
}
```
![](http://siegrain.wang/_image/2018-01-22-10-31-41.jpg)

##4. 最后一步，让请求支持缓存
关于缓存这一功能，我在演示项目中集成的只是最基本的需求，非常地简单粗暴，仅仅有缓存和定时过期两个功能，具体情形各位应根据需求自行调整，这里我采用了`AwesomeCache`这个库来实现。

首先，声明`AwesomeCache`对象（仅用于项目演示）：
```swift
import AwesomeCache

private let globalCache = try! Cache<NSString>(name: "globalCache")
private let cacheExpireDate = CacheExpiry.seconds(60*60*24)
```

在我们其中一个`CallApi()`方法中实现缓存功能，并指定其过期时间：
```swift
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
```
好，测试一下。
```swift
// 缓存
firstly { () -> Promise<[String: Any]> in
    return CallApi(ZhihuAPI.latest, isCached: true)
}.then { [weak self] (result) -> Void in
    self?.textView.text = "\(result)"
}
```
![](http://siegrain.wang/_image/2018-01-22-11-12-55.jpg)
如日志所示，分别是第一次请求和第二次请求。
其他`CallApi()`方法的缓存功能按类似的方式实现即可。
