# orange-plugin-blacklist
从reids中获取拦截黑名单,进行拦截
# 配置使用方法
1. 移动`blacklist`文件夹到`<orange-install-path>/orange/plugins`下
2. 修改配置文件`orange.conf`,添加`blacklist`到插件中
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
3. 添加`redis.conf`配置文件在`orange.conf`同一个路径下,格式如下:
    ```
    {
        "server": "127.0.0.1",
        "port":	6379,
        "timeout": 2000,
        "pool_max_idle_time": 20000,
        "pool_size": 50
    }
    ```
3. 此时,可以通过命令`curl -d "enable=1" "http://host:9999/blacklist/enable"`开启插件的使用
#### 添加可视化功能(可选)
1. 复制文件`dashboard/blacklist.html`到`<orange-path>/dashboard/views`下
1. 复制文件`dashboard/blacklist.js`到`<orange-path>/dashboard/static/js`下
1. 将文件`dashboard/left_nav.html`替换到`<orange-path>/dashboard/views/common`下的同名文件
1. 将文件`dashboard/dashboard.lua`替换到`<orange-path>/dashboard/routes`下的同名文件
