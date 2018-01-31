(function (L) {
    var _this = null;
    L.Blacklist = L.Blacklist || {};
    _this = L.Blacklist = {
        data: {
        },

        init: function () {
            _this.initEvents();

            var op_type = "blacklist";
            $.ajax({
                url: '/blacklist/config',
                type: 'get',
                cache: false,
                data: {},
                dataType: 'json',
                success: function (result) {
                    if (result.success) {
                        L.Common.resetSwitchBtn(result.data.enable, op_type);
                        $("#switch-btn").show();
                        $("#view-btn").show();
                        var enable = result.data.enable;

                        //重新设置数据
                        _this.data.enable = enable;

                        $("#op-part").css("display", "block");
                    } else {
                        $("#op-part").css("display", "none");
                        L.Common.showErrorTip("错误提示", "查询" + op_type + "配置请求发生错误");
                    }
                },
                error: function () {
                    $("#op-part").css("display", "none");
                    L.Common.showErrorTip("提示", "查询" + op_type + "配置请求发生异常");
                }
            });
        },

        initEvents: function(){
            var op_type = "blacklist";
            L.Common.initViewAndDownloadEvent(op_type, _this);
            L.Common.initSwitchBtn(op_type, _this);//redirect关闭、开启
            L.Common.initSyncDialog(op_type, _this);//编辑规则对话框
        },
    };
}(APP));
