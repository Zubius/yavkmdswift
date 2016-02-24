#!/usr/bin/swift

import Foundation

struct VKUser {
    var Token : String = ""
    var UserId = 0
}

struct VKMusicResponse {
    var Response : VKMusic
}

struct VKMusic {
    var Count = 0
    var Items = [VKMusicItem]()
    var TrackSet = Set<Int>()
}

struct VKMusicItem {
    var Artist : String = ""
    var Title : String = ""
    var Url : String = ""
    var Id = 0
}

let userName = Process.arguments[1]
let password = Process.arguments[2]
var UserId = 0
var specificId = Process.arguments.count == 4
if (specificId) {
    UserId = Int(Process.arguments[3])!
}

func ParseJsonMusic(json : String) -> VKMusic {
    var music = VKMusic()
    if let jdata: NSData = json.dataUsingEncoding(NSUTF8StringEncoding) {
        do {
            if let jsonObj = try NSJSONSerialization.JSONObjectWithData(jdata, options: NSJSONReadingOptions(rawValue: 0)) as? Dictionary<String, AnyObject> {
                let items = jsonObj["response"]!["items"]!!
                print(items.count)
                music.Count = items.count
                music.Items = [VKMusicItem](count:items.count, repeatedValue: VKMusicItem())
                for i in 0..<items.count {
                    music.Items[i].Artist = (jsonObj["response"]!["items"]!![i]["artist"] as? String)!
                    music.Items[i].Title = (jsonObj["response"]!["items"]!![i]["title"] as? String)!
                    music.Items[i].Url = (jsonObj["response"]!["items"]!![i]["url"] as? String)!
                    music.Items[i].Id = ((jsonObj["response"]!["items"]!![i]["id"] as? Int)!)
                    music.TrackSet.insert((jsonObj["response"]!["items"]!![i]["id"] as? Int)!)
                }
                return music
            }
        } catch {
            return music
        }
    }
    return music
}

func ParseJsonAuth(json : String) -> VKUser {
    var user = VKUser()
    if let jdata: NSData = json.dataUsingEncoding(NSUTF8StringEncoding) {
        do {
            if let jsonObj = try NSJSONSerialization.JSONObjectWithData(jdata, options: NSJSONReadingOptions(rawValue: 0)) as? Dictionary<String, AnyObject> {
                if let token = jsonObj["access_token"] as? String {
                    user.Token = token
                }
                if let id = jsonObj["user_id"] as? Int {
                    user.UserId = specificId ? UserId : id
                }
                return user
            }
        } catch {
            return user
        }
    }
    return user
}


func HTTPGetRequest(url : String, callback: (String) -> Void) {
    let url = NSURL(string: url)
    
    let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
        let dataString = NSString(data: data!, encoding: NSUTF8StringEncoding)
        //print(dataString as! String)
        callback(dataString as! String)
    }
    
    
    task.resume()
}

func HTTPDownload(item : VKMusicItem, callback: (VKMusicItem) -> Void) {
    let url = NSURL(string: item.Url)
//    print("Start Download: \(item.Artist) - \(item.Title).mp3")
    let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
    	if error == nil {
        	if let dir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.MusicDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
        		let docDir : AnyObject = dir
            	let folder = docDir.stringByAppendingPathComponent("VKMusic")
            	let path = (folder as NSString).stringByAppendingPathComponent("\(item.Artist) - \(item.Title).mp3");
            	data!.writeToFile(path, atomically: true)
                print("Downloaded: \(item.Artist) - \(item.Title).mp3")
        	}
        } else {
        	print("---   \(item.Artist) - \(item.Title).mp3 Didn't downloaded: \(error!.localizedDescription as String)")
        }
        callback(item)
    }
    
    
    task.resume()
}

func GetVKToken(callback: (VKUser) -> Void) {
    HTTPGetRequest("https://oauth.vk.com/token?grant_type=password&client_id=2274003&client_secret=hHbZxrka2uZ6jB1inYsH&username=\(userName)&password=\(password)&scope=audio,offline") {
        (data : String) -> Void in
        let user = ParseJsonAuth(data)
        callback(user)
    }
}

GetVKToken() {
    (user : VKUser) -> Void in
    HTTPGetRequest("https://api.vk.com/method/audio.get?owner_id=\(user.UserId)&v=5.45&count=6000&access_token=\(user.Token)") {(data : String) -> Void in
        var music = ParseJsonMusic(data)
        if let dir = NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory.MusicDirectory, NSSearchPathDomainMask.AllDomainsMask, true).first {
            let docDir : AnyObject = dir
            let folder = docDir.stringByAppendingPathComponent("VKMusic")
            do {
                try NSFileManager.defaultManager().createDirectoryAtPath(folder, withIntermediateDirectories: false, attributes: nil)
            }
            catch {
                
            }
        }
        for i in 0..<music.Items.count {
        	HTTPDownload(music.Items[i]) {(item : VKMusicItem) -> Void in
                music.TrackSet.remove(item.Id)
                if music.TrackSet.count == 0 {
                    exit(0)
                }
            }
        }
    }
}

readLine()
