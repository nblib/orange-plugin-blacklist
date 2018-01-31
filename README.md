# orange-plugin-blacklist
从reids中获取拦截黑名单,进行拦截
# 配置使用方法
####### 移动`blacklist`文件夹到`<orange-install-path>/orange/plugins`下
####### 修改配置文件`orange.conf`,添加`blacklist`到插件中
```
"plugins": [
        "stat",
        "monitor",
        "redirect",
        "rewrite",
        "rate_limiting",
        "property_rate_limiting",
        "basic_auth",
        "key_auth",
        "signature_auth",
        "waf",
        "divide",
        "kvstore",
		"blacklist"
    ],
```
####### 此时,可以通过命令`curl -d "enable=1" "http://host:9999/blacklist/enable"`开启插件的使用

