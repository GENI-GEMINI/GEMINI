
// TODO: Get some opts from cookies?
var defOptionsUtil = {
        "resolution":   5,
//        "resolution":   10,
        "npoints":   72,
        "fakeServiceMode": 0,
        "xOriginIsZero": false,
        "axisLabelFontSize": 18,
        "axisLabelColor": Color.blackColor(),
        "axisLineColor":    Color.lightGrayColor(),
        "padding": {
            "left": 30,
            "right": 20,
            "top": 0,
            "bottom": 10},
        "yAxis":[0,10000],
        "yTicks":[
        {label: "0", v: 0},
        {label: "2", v: 2000},
        {label: "4", v: 4000},
        {label: "6", v: 6000},
        {label: "8", v: 8000},
        {label: "10", v: 10000},
        ]
    };
var layout = null;
var renderer = null;
var goUtil = true;

function loadDataUtil(req) {

    if(!goUtil) return;

//    log("JSON:",req.responseText);
//    log("PRE: evalJSON", Date());
    var json = MochiKit.Async.evalJSONRequest(req);
//    log("POST: evalJSON", Date());

    // XXX: Can remove when Jason corrects service
    // removes any trailing 0 data. (rrd is still modifying these)
    while(json.servdata.data.length > 1){
        var arrElem = json.servdata.data[json.servdata.data.length-1];
        var val;
        if(arrElem.length > 1){
            val = arrElem[1];
        }
        else{
            val = arrElem;
        }

        if(val != 0){
            break;
        }

        json.servdata.data.length--;
    }

    // Add a 0 data value to beginning and end of rrd data to deal
    // with lame PlotKit desire to draw to the corners.

    var data = json.servdata.data;
    data.splice(0,0,[json.servdata.data[0][0] - 1, 0]);
    data[data.length] =
            [json.servdata.data[json.servdata.data.length-1][0]+1,0];

    layout.addDataset("sample",data);

    var i;
    var morig,mnew,sec;
    var mnDate = new Date(json.servdata.data[0][0]*1000);
    var mxDate = new Date(
            json.servdata.data[json.servdata.data.length-1][0]*1000);

    // TODO:
    // totally hacked assuming 1000 seconds of spread from min-max
    // Need to do something real here...

    // tick every 2 minutes (replaced with 1 for now)
    sec = mnDate.getSeconds();
    morig = mnDate.getMinutes();
    mnew = Math.floor(morig/1.0) * 1;
    // make changes to Date object using increments of millisecs so
    // all date arithmetic is handled by "Date".
    i = json.servdata.data[0][0]-sec; // min boundry
    i -= (morig-mnew)*60;
    mnDate = new Date(i*1000);

    sec = mxDate.getSeconds();
    morig = mxDate.getMinutes();
    i=0;
    if(sec){
        morig++;
        i = 60-sec;
    }
    mnew = Math.ceil(morig/1.0) * 1;
    i += json.servdata.data[json.servdata.data.length-1][0]; // min boundry
    i += (mnew-morig)*60;
    mxDate = new Date(i*1000);

    var dateOptions = [];
    var ticks = [];
    var mn = mnDate.valueOf()/1000;
    var mx = mxDate.valueOf()/1000;

    dateOptions.xAxis = [mn,mx];
//    for(i=mn;i<=mx;i+=120){
    for(i=mn;i<=mx;i+=60){
        mnDate = new Date(i*1000);
        mnew = mnDate.getMinutes();
        ticks.push({label: mnew, v: i});
    }
    dateOptions.xTicks = ticks;

    MochiKit.Base.update(layout.options,dateOptions);
    MochiKit.Base.update(renderer.options,dateOptions);

    layout.evaluate();
    renderer.clear();
    renderer.render();

    MochiKit.Async.callLater(defOptionsUtil.resolution,newDataUtil);
}

function newDataUtil(){
    if(!goUtil) return;

    var query = "updateData.cgi";
    query +="?resolution="+defOptionsUtil.resolution+"&npoints="+defOptionsUtil.npoints+"&fakeServiceMode="+defOptionsUtil.fakeServiceMode+"&";
    if(getHost){
        query += "hostName="+getHost()+"&";
    }
    if(getInterface){
        query += "ifIndex="+getInterface()+"&";
    }
    if(getDirection){
        query += "direction="+getDirection()+"&";
    }
//    log("Fetch Data: ", Date());
    // TODO: Change to POST and specify args
    var doreq = MochiKit.Async.doSimpleXMLHttpRequest(query);
    doreq.addCallback(loadDataUtil);
}

function startStopUtil(){
    goUtil = !goUtil;

    if(goUtil){
        $('start-stop-util').value = "Stop";
//        log("Starting data loop", Date());
        newDataUtil();
    }
    else{
//        log("Stopping data loop", Date());
        $('start-stop-util').value = "Start";
    }
}

var utilOptions = {
    "plotCanvasName":   "plot"
//  "startStopName":    "start-stop-util"
};

function initGraph(){
    layout = new PlotKit.Layout("line",defOptionsUtil);

    newDataUtil();

    renderer = new SweetCanvasRenderer($(utilOptions.plotCanvasName),
            layout,defOptionsUtil);
//    if(utilOptions.startStopName !== undefined){
//        MochiKit.Signal.connect(utilOptions.startStopName, 'onclick',
//                                                            startStopUtil);
//    }
}
