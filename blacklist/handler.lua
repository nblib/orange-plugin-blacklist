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
local redis_default = {pool_max_idle_time = 10000,pool_size=100,timeout=1000,port=6379,timerdelay=300}
local redisConfig = {}
-- redis 相关
local function close_redis(red)  
    if not red then  
        return  
    end  
    --释放连接(连接池实现)  
    local ok, err = red:set_keepalive(redisConfig.pool_max_idle_time, redisConfig.pool_size)  
    if not ok then  
        ngx.log(ngx.ERR,"[blacklist-plugin]set keepalive error : ", err)  
    end  
end  


-- 加载 reids配置
function LoadRedisConfig()
	local env_orange_conf = os.getenv("ORANGE_CONF")
	local config_file = env_orange_conf or ngx.config.prefix().. "/conf/redis.conf"
	config_file = string.gsub(config_file,"orange%.conf","redis.conf")
	ngx.log(ngx.DEBUG,"[blacklist-plugin]load config path",config_file)
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
	redisConfig = setmetatable(config,{ __index = redis_default })

end
-- 根据ip判断是否禁止,是返回true
function isBanIp(var_ip)
	local sharedDict = ngx.shared.blacklist_list
	if not sharedDict then
		ngx.log(ngx.ERR,"[blacklist-plugin]not set shared dic [blacklist_list]")
		return false
	end
	-- 根据isNew子段是否存在判断是否需要更新,存在不需要
	local isNew = sharedDict:get("isNew")
	
	if isNew then 
		
		return sharedDict:get(var_ip)
	end
	
	-- 不是最新,需要更新

	--创建实例  
	local red = redis:new()  
	--设置超时（毫秒）  
	red:set_timeout(redisConfig.timeout)  
	--建立连接  
	local ip = redisConfig.server 
	local port = redisConfig.port
	if not ip or ip == "" then
		ngx.log(ngx.ERR,"[blacklist-plugin]get config redis server is null, check if config load correctly! : ") 
		return false
	end
	local ok, err = red:connect(ip, port)  
	if not ok then  
	    ngx.log(ngx.ERR,"[blacklist-plugin]connect to redis error : ", err)  
	    close_redis(red)  
		return false
	end  

	--调用API获取数据  
	local resp, err = red:get("openretry_orange_blacklist_ips")
	if not resp then  
	    ngx.log(ngx.ERR,"[blacklist-plugin]get msg error : ", err)  
	    close_redis(red)  
		return false
	end  
	close_redis(red)
	--得到的数据为空处理,这里的空指的是成功从redis中获取返回值,而这个值在redis中确实是空的
	if resp == ngx.null then  
		ngx.log(ngx.WARN,"[blacklist-plugin]black list is empty,access")
	    return false
	end  
	
	-- 解析json
	local blacklistTable,err = json.decode(resp)
	if err then
		ngx.log(ngx.ERR,"[blacklist-plugin]parse json error,",err)
		return false
	end
	
	-- 保存标志位
	success, err, forcible = sharedDict:set("isNew","true",redisConfig.timerdelay)
	if not success then
		ngx.log(ngx.ERR,"[blacklist-plugin]set shared dict error: ",err,"key is :"..v)
		return false
	end
	if blacklistTable["ips"] then
		local ips = blacklistTable["ips"]
		for k,v in pairs(ips) do
			success, err, forcible=sharedDict:set(v,"true",redisConfig.timerdelay + 60)
			if not success then
				ngx.log(ngx.ERR,"[blacklist-plugin]set shared dict error: ",err,"key is :"..v)
			end
		end
	end
	
	ngx.log(ngx.INFO,"[blacklist-plugin] sync from redis success")
	return sharedDict:get(var_ip)
end

-- 初始化阶段
function BlacklistHandler:init_worker()
	-- 加载redis配置文件
    LoadRedisConfig()
end
-- 访问阶段
function BlacklistHandler:access(conf)
    BlacklistHandler.super.access(self)

    local enable = orange_db.get("blacklist.enable")
   
   
    if not enable or enable ~= true  then
        return
    end


	-- 获取用户真实ip
	local headers = ngx.req.get_headers()
	local ngx_var_ip = headers["X-REAL-IP"] or headers["X_FORWARDED_FOR"] or ngx.var.remote_addr or "0.0.0.0"
    ngx.log(ngx.DEBUG,"[blacklist-plugin]remote addr",ngx_var_ip)
	-- 拦截
	
	local ipexist = isBanIp(ngx_var_ip)
	if ipexist then
		ngx.log(ngx.INFO,"[blacklist-plugin]forbidden ip:	",ngx_var_ip)
		return ngx.exit(403)
	end
	
end

  


return BlacklistHandler
