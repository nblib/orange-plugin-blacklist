local pairs = pairs
local ipairs = ipairs

local orange_db = require("orange.store.orange_db")
local handle_util = require("orange.utils.handle")
local BasePlugin = require("orange.plugins.base_handler")
local json = require("orange.utils.json")
local IO = require("orange.utils.io")

local redis = require("resty.redis")

local BlacklistHandler = BasePlugin:extend()
BlacklistHandler.PRIORITY = 2000

function BlacklistHandler:new(store)
    BlacklistHandler.super.new(self, "blacklist-plugin")
    self.store = store
end

-- redis default config
local redis_default = { pool_max_idle_time = 10000, pool_size = 100, timeout = 1000, port = 6379 }
local redisConfig = {}
-- redis 相关
local function close_redis(red)
    if not red then
        return
    end
    --释放连接(连接池实现)  
    local ok, err = red:set_keepalive(redisConfig.pool_max_idle_time, redisConfig.pool_size)
    if not ok then
        ngx.log(ngx.ERR, "[blacklist-plugin]set keepalive error : ", err)
    end
end


-- 加载 reids配置
function LoadRedisConfig()
    local env_orange_conf = os.getenv("ORANGE_CONF")
    local config_file = env_orange_conf or ngx.config.prefix() .. "/conf/redis.conf"
    config_file = string.gsub(config_file, "orange%.conf", "redis.conf")
    ngx.log(ngx.DEBUG, "[blacklist-plugin]load config path", config_file)
    -- 读取文件
    local config_contents = IO.read_file(config_file)

    if not config_contents then
        ngx.log(ngx.ERR, "No configuration file at: ", config_file)
        return
    end

    local config = json.decode(config_contents)
    if not config then
        config = {}
    end
    redisConfig = setmetatable(config, { __index = redis_default })

end

-- 初始化阶段
function BasePlugin:init_worker()
    -- 加载redis配置文件
    LoadRedisConfig()
end
-- 访问阶段
function BlacklistHandler:access(conf)
    BlacklistHandler.super.access(self)

    local enable = orange_db.get("blacklist.enable")

    if not enable or enable ~= true then
        return
    end

    --创建实例
    local red = redis:new()
    --设置超时（毫秒）
    red:set_timeout(redisConfig.timeout)
    --建立连接
    local ip = redisConfig.server
    local port = redisConfig.port
    if not ip or ip == "" then
        ngx.log(ngx.ERR, "[blacklist-plugin]get config redis server is null, check if config load correctly! : ")
        return
    end
    local ok, err = red:connect(ip, port)
    if not ok then
        ngx.log(ngx.ERR, "[blacklist-plugin]connect to redis error : ", err)
        return close_redis(red)
    end

    --调用API获取数据
    local resp, err = red:get("openretry_orange_blacklist_ips")
    if not resp then
        ngx.log(ngx.ERR, "[blacklist-plugin]get msg error : ", err)
        return close_redis(red)
    end
    close_redis(red)
    --得到的数据为空处理,这里的空指的是成功从redis中获取返回值,而这个值在redis中确实是空的
    if resp == ngx.null then
        ngx.log(ngx.WARN, "[blacklist-plugin]black list is empty,access")
        return
    end

    -- 解析json
    local blacklistTable, err = json.decode(resp)
    if err then
        ngx.log(ngx.ERR, "[blacklist-plugin]parse json error,", err)
        return
    end
    ngx.log(ngx.DEBUG, "[blacklist-plugin]msg : ", table.concat(blacklistTable["ips"]))
    -- 获取用户真实ip
    local headers = ngx.req.get_headers()
    local ngx_var_ip = headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"

    ngx.log(ngx.DEBUG, "[blacklist-plugin]remote addr", ngx_var_ip)
    -- 拦截
    if blacklistTable["ips"] then
        for k, v in pairs(blacklistTable["ips"]) do
            if v == ngx_var_ip then
                ngx.log(ngx.INFO, "[blacklist-plugin]forbidden an ip:	", v)
                ngx.exit(403)
                break
            end
        end
    end

end

return BlacklistHandler
