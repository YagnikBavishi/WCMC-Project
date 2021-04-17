import "package:flutter/material.dart";
import 'package:flutter/services.dart';
import "dart:collection";
import "dart:async";
import "dart:io";
import "package:intl/intl.dart";
import "dart:convert";
import "package:web_socket_channel/io.dart";
import "package:http/http.dart" as http;
import "package:url_launcher/url_launcher.dart";
import "package:path_provider/path_provider.dart";
import "package:local_database/local_database.dart";
import "package:auto_size_text/auto_size_text.dart";
import "dart:math";
import "package:syncfusion_flutter_charts/charts.dart";
import "package:syncfusion_flutter_core/core.dart";
import "image_keys.dart";
import "package:flutter_svg/flutter_svg.dart";
import 'package:splashscreen/splashscreen.dart';

String _api = "https://api.coincap.io/v2/";
HashMap<String, Map<String, dynamic>> _coinData;
HashMap<String, ValueNotifier<num>> _valueNotifiers =
    HashMap<String, ValueNotifier<num>>();
List<String> _savedCoins;
Database _userData;
Map<String, dynamic> _settings;
String _symbol;
LinkedHashSet<String> _supportedCurrencies = LinkedHashSet.from([
  "USD",
  "AUD",
  "BGN",
  "BRL",
  "CAD",
  "CHF",
  "CNY",
  "CZK",
  "DKK",
  "EUR",
  "GBP",
  "HKD",
  "HRK",
  "HUF",
  "IDR",
  "ILS",
  "INR",
  "ISK",
  "JPY",
  "KRW",
  "MXN",
  "MYR",
  "NOK",
  "NZD",
  "PHP",
  "PLN",
  "RON",
  "RUB",
  "SEK",
  "SGD",
  "THB",
  "TRY",
  "ZAR"
]);
Map<String, dynamic> _conversionMap;
num _exchangeRate;
bool _loading = false;
Future<dynamic> _apiGet(String link) async{
  return json.decode((await http.get(Uri.encodeFull("$_api$link"))).body);
}

void _changeCurrency(String currency){
  var conversionData = _conversionMap[_settings["currency"]];
  _exchangeRate = conversionData["rate"];
  _symbol = conversionData["symbol"];
}
void main() async{
  WidgetsFlutterBinding.ensureInitialized();
 // SyncfusionLicense.registerLicense(syncKey);
  _userData = Database((await getApplicationDocumentsDirectory()).path);
  _savedCoins = (await _userData["saved"])?.cast<String>() ?? [];
  _settings = await _userData["settings"];
  if(_settings==null){
    _settings = {
      "disableGraphs":false,
      "currency":"USD"
    };
    _userData["settings"] = _settings;
  }
  var exchangeData = json.decode(
      (await http.get("https://api.coincap.io/v2/rates")).body
  )["data"];
  _conversionMap = HashMap();
  for(dynamic data in exchangeData){
    String symbol = data["symbol"];
    if(_supportedCurrencies.contains(symbol)){
      _conversionMap[symbol] = {
        "symbol": data["currencySymbol"] ?? "",
        "rate": 1/num.parse(data["rateUsd"])
      };
    }
  }
  _changeCurrency(_settings["currency"]);
  _coinData = HashMap<String,Map<String,Comparable>>();
  runApp(new MaterialApp(
    debugShowCheckedModeBanner: false,
    home: new MySplash(),
    theme: new ThemeData(
      primarySwatch: Colors.green,
    ),
  ));
}

class MySplash extends StatefulWidget {
  @override
  _MySplashState createState() => _MySplashState();
}

class _MySplashState extends State<MySplash> {
  @override
  Widget build(BuildContext context) {
    return SplashScreen(
      seconds: 5,
      backgroundColor: Color(0xff7f5a83),

      image: Image.asset("icon/platypus6.png"),
      photoSize: 120.0,
      loaderColor: Color(0xff0d324d),
      navigateAfterSeconds: App(),
      loadingText: Text(
        "Welcome to CryptoCurrency Analysis...",
        style: new TextStyle(color: Color(0xff0d324d), fontSize: 20.0),
      ),
    );
  }
}



class App extends StatefulWidget {
  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    setUpData();
  }

    IOWebSocketChannel socket;

  Future<void> setUpData() async{
    _coinData = HashMap<String,Map<String,Comparable>>();
    _loading = true;
    setState((){});
    var data = (await _apiGet("assets?limit=2000"))["data"];
    data.forEach((e){
      String id = e["id"];
      _coinData[id] = e.cast<String,Comparable>();
      _valueNotifiers[id] = ValueNotifier(0);
      for(String s in e.keys){
        if(e[s]==null){
          e[s]=(s=="changePercent24Hr"?-1000000:-1);
        }else if(!["id","symbol","name"].contains(s)){
          e[s] = num.parse(e[s], (e) => null);
        }
      }
    });
    _loading = false;
    setState((){});
    socket?.sink?.close();
    socket = IOWebSocketChannel.connect("wss://ws.coincap.io/prices?assets=ALL");
    socket.stream.listen((message){
      Map<String,dynamic> data = json.decode(message);
      data.forEach((s,v){
        if(_coinData[s]!=null){
          num old = _coinData[s]["priceUsd"];
          _coinData[s]["priceUsd"]=num.parse(v)??-1;
          _valueNotifiers[s].value = old;
        }
      });
    });
  }
//backgroud color
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
            ),
        debugShowCheckedModeBanner: false,
        home: ListPage(true));
  }
}

String sortingBy;

//setting  button code

class Setting extends StatefulWidget {
  _SettingState createState() => _SettingState();

}

class _SettingState extends State<Setting>{
  
Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Setting',
      home: Scaffold(
        appBar: AppBar(
          title: (
            Text('Setting')
          ),
          backgroundColor: Color(0xff7f5a83),
        ),
        body: Padding(
            padding: EdgeInsets.only(top:20.0,right:15,left:15),
                child: ListView(
                physics: ClampingScrollPhysics(),
                children: [
                  Card(
                    color: Color(0xff7f5a83),
                    child: ListTile(
                        title: Text("Change Currency"),
                        subtitle: Text("33 fiat currency options"),
                        trailing: Padding(
                            child: Container(
                                color: Colors.white12,
                                padding: EdgeInsets.only(right:7.0,left:7.0),
                                child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                        value: _settings["currency"],
                                        onChanged: (s){
                                          _settings["currency"] = s;
                                          _changeCurrency(s);
                                          _userData["settings/currency"] = s;
                                          context.findAncestorStateOfType<_AppState>().setState((){});
                                        },
                                        items: _supportedCurrencies.map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text("$s ${_conversionMap[s]["symbol"]}")
                                        )).toList()                                    )
                                )
                            ),
                            padding: EdgeInsets.only(right:10.0)
                        )
                    ),
                    margin: EdgeInsets.zero,
                  )
                ]
            )
        
      ),
        ),
          debugShowCheckedModeBanner: false,

    );
  }
}

//String sortingBy;

class ListPage extends StatefulWidget {

  final bool savedPage;

  ListPage(this.savedPage) : super(key:ValueKey(savedPage));

  @override
  _ListPageState createState() => _ListPageState();
}

typedef SortType(String s1, String s2);

SortType sortBy(String s){
  String sortVal = s.substring(0,s.length-1);
  bool ascending = s.substring(s.length-1).toLowerCase()=="a";
  return (s1,s2){
    if(s=="custom"){
      return _savedCoins.indexOf(s1)-_savedCoins.indexOf(s2);
    }
    Map<String,Comparable> m1 = _coinData[ascending?s1:s2], m2 = _coinData[ascending?s2:s1];
    dynamic v1 = m1[sortVal], v2 = m2[sortVal];
    if(sortVal=="name"){
      v1 = v1.toUpperCase();
      v2 = v2.toUpperCase();
    }
    int comp = v1.compareTo(v2);
    if(comp==0){
      return sortBy("nameA")(s1,s2) as int;
    }
    return comp;
  };
}


class _ListPageState extends State<ListPage> {
  bool searching = false;

  List<String> sortedKeys;
  String prevSearch = "";

  void reset() {
    if (widget.savedPage) {
      sortedKeys = List.from(_savedCoins)..sort(sortBy(sortingBy));
    } else {
      sortedKeys = List.from(_coinData.keys)..sort(sortBy(sortingBy));
    }
    setState(() {});
  }

  void search(String s) {
    scrollController.jumpTo(0.0);
    reset();
    moving = false;
    moveWith = null;
    for (int i = 0; i < sortedKeys.length; i++) {
      String key = sortedKeys[i];
      String name = _coinData[key]["name"];
      String ticker = _coinData[key]["symbol"];
      if (![name, ticker]
          .any((w) => w.toLowerCase().contains(s.toLowerCase()))) {
        sortedKeys.removeAt(i--);
      }
    }
    prevSearch = s;
    setState(() {});
  }

  void sort(String s) {
    scrollController.jumpTo(0.0);
    moving = false;
    moveWith = null;
    sortingBy = s;
    setState(() {
      sortedKeys.sort(sortBy(s));
    });
  }

  @override
  void initState() {
    super.initState();
    sortingBy = widget.savedPage ? "custom" : "marketCapUsdD";
    reset();
  }

  Timer searchTimer;
  ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    Widget ret = Scaffold(
        appBar: AppBar(
          title: (Text("CryptoCurrency Analysis")),
          backgroundColor: Color(0xff7f5a83),
          actions: <Widget>[
            IconButton(
              icon: Icon(
                Icons.settings,
                color: Colors.white,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Setting()),
                );
              },
            )
          ],
        ),
        body: !_loading
            ? Scrollbar(
                child: Container(
                      decoration: BoxDecoration(
                      gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xff7f5a83), //bdc3c7 or 004e92 or 2b5876
                        Color(0xff0d324d) //2c3e50 or 000428  or 4e4376
                      ],
                    )),
                    child: ListView.builder(
                        itemBuilder: (context, i) =>
                            Crypto(sortedKeys[i], widget.savedPage),
                        itemCount: sortedKeys.length,
                        controller: scrollController)))
            : Container(),
        floatingActionButton: widget.savedPage
            ? !_loading
                ? FloatingActionButton(
                    //plus button first  page
                    onPressed: () {
                      moving = false;
                      moveWith = null;
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => ListPage(false))).then((d) {
                        sortingBy = "custom";
                        searching = false;
                        reset();
                        scrollController.jumpTo(0.0);
                      });
                    },
                    child: Icon(Icons.add),
                    heroTag: "newPage")
                : null
            : FloatingActionButton(

                //All coin page plus button
                 onPressed: () {
                   scrollController.jumpTo(0.0);
                 },
                child: Icon(
              Icons.arrow_upward
          ),
          heroTag: "jump"));
    if (!widget.savedPage) {
      ret = WillPopScope(
          child: ret, onWillPop: () => Future<bool>(() => !_loading));
    }
    return ret;
  }
}

bool _didImport = false;

class PriceText extends StatefulWidget {
  final String id;

  PriceText(this.id);

  @override
  _PriceTextState createState() => _PriceTextState();
}

class _PriceTextState extends State<PriceText> {
  Color changeColor;
  Timer updateTimer;
  bool disp = false;
  ValueNotifier<num> coinNotif;
  Map<String, dynamic> data;

  void update() {
    if (data["priceUsd"].compareTo(coinNotif.value) > 0) {
      changeColor = Colors.green;
    } else {
      changeColor = Colors.red;
    }
    setState(() {});
    updateTimer?.cancel();
    updateTimer = Timer(Duration(milliseconds: 400), () {
      if (disp) {
        return;
      }
      setState(() {
        changeColor = null;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    data = _coinData[widget.id];
    coinNotif = _valueNotifiers[widget.id];
    coinNotif.addListener(update);
  }

  @override
  void dispose() {
    super.dispose();
    disp = true;
    coinNotif.removeListener(update);
  }

//Price Changes of coin
  @override
  Widget build(BuildContext context) {
    num price = data["priceUsd"] * _exchangeRate;
    return Text(
        price >= 0
            ? NumberFormat.currency(
                    symbol: _symbol,
                    decimalDigits: price > 1
                        ? price < 100000
                            ? 2
                            : 0
                        : price > .000001
                            ? 6
                            : 7)
                .format(price)
            : "N/A",
        style: TextStyle(
            fontSize: 20.0, fontWeight: FontWeight.bold, color: changeColor));
  }
}

bool moving = false;
String moveWith;

class Crypto extends StatefulWidget {
  final String id;
  final bool savedPage;

  Crypto(this.id, this.savedPage)
      : super(key: ValueKey(id + savedPage.toString()));

  @override
  _CryptoState createState() => _CryptoState();
}

class _CryptoState extends State<Crypto> {
  bool saved;
  Map<String, dynamic> data;

  @override
  void initState() {
    super.initState();
    data = _coinData[widget.id];
    saved = _savedCoins.contains(widget.id);
  }

  void move(List<String> coins) {
    int moveTo = coins.indexOf(widget.id);
    int moveFrom = coins.indexOf(moveWith);
    coins.removeAt(moveFrom);
    coins.insert(moveTo, moveWith);
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    num mCap = data["marketCapUsd"];
    mCap *= _exchangeRate;
    num change = data["changePercent24Hr"];
    String shortName = data["symbol"];
    return Container(
        padding: EdgeInsets.only(top: 10.0),
        child: GestureDetector(
            child: Dismissible(
                background: Container(color: Colors.red),
                key: ValueKey(widget.id),
                direction: DismissDirection.endToStart,
                onDismissed: (d) {
                  _savedCoins.remove(widget.id);
                  _userData["saved"] = _savedCoins;
                  context
                      .findAncestorStateOfType<_ListPageState>()
                      .sortedKeys
                      .remove(widget.id);
                  context
                      .findAncestorStateOfType<_ListPageState>()
                      .setState(() {});
                },

                // Disble the graph page in first page

                child: FlatButton(
                  onPressed: () {
                    if (widget.savedPage) {
                      if (moving) {
                        move(_savedCoins);
                        move(context
                            .findAncestorStateOfType<_ListPageState>()
                            .sortedKeys);
                        setState(() {
                          moveWith = null;
                          moving = false;
                        });
                        context
                            .findAncestorStateOfType<_ListPageState>()
                            .setState(() {});
                        _userData["saved"] = _savedCoins;
                      } else {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => ItemInfo(widget.id)));
                      }
                    } else {
                      setState(() {
                        if (saved) {
                          saved = false;
                          _savedCoins.remove(widget.id);
                          _userData["saved"] = _savedCoins;
                        } else {
                          saved = true;
                          _savedCoins.add(widget.id);
                          _userData["saved"] = _savedCoins;
                        }
                      });
                    }
                  },

                  padding: EdgeInsets.only(
                      top: 15.0, bottom: 15.0, left: 5.0, right: 5.0),
                  child: Row(
                    children: [
                      Expanded(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                            Row(children: [
                              ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: width / 3),
                                  child: AutoSizeText(data["name"],
                                      maxLines: 2,
                                      minFontSize: 0.0,
                                      maxFontSize: 17.0,
                                      style: TextStyle(fontSize: 17.0)))
                            ]),
                            Container(height: 5.0),
                            Row(children: [
                              FadeInImage(
                                  image: !blacklist.contains(widget.id)
                                      ? NetworkImage(
                                          "https://static.coincap.io/assets/icons/${shortName.toLowerCase()}@2x.png")
                                      : AssetImage("icon/platypus2.png"),
                                  placeholder: AssetImage("icon/platypus2.png"),
                                  fadeInDuration:
                                      const Duration(milliseconds: 100),
                                  height: 32.0,
                                  width: 32.0),
                              Container(width: 4.0),
                              ConstrainedBox(
                                  constraints:
                                      BoxConstraints(maxWidth: width / 3 - 40),
                                  child: AutoSizeText(shortName, maxLines: 1))
                            ])
                          ])),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            PriceText(widget.id),
                            Text(
                                (mCap >= 0
                                    ? mCap > 1
                                        ? _symbol +
                                            NumberFormat.currency(
                                                    symbol: "",
                                                    decimalDigits: 0)
                                                .format(mCap)
                                        : _symbol + mCap.toStringAsFixed(2)
                                    : "N/A"),
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 12.0)),
                            !_settings["disableGraphs"]
                                ? linkMap[shortName] != null &&
                                        !blacklist.contains(widget.id)
                                    ? SvgPicture.network(
                                        "https://www.coingecko.com/coins/${linkMap[shortName] ?? linkMap[widget.id]}/sparkline",
                                        placeholderBuilder:
                                            (BuildContext context) => Container(
                                                width: 0, height: 35.0),
                                        width: 0,
                                        height: 0)
                                    : Container(height: 35.0)
                                : Container(),
                          ]),
                      Expanded(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                            change != -1000000.0
                                ? Text(
                                    ((change >= 0) ? "+" : "") +
                                        change.toStringAsFixed(3) +
                                        "\%",
                                    style: TextStyle(
                                        color: ((change >= 0)
                                            ? Colors.green
                                            : Colors.red)))
                                : Text("N/A"),
                            Container(width: 2),

                            //Plus button in all coins page in list view

                            !widget.savedPage
                                ? Icon(saved ? Icons.star : Icons.star_outline_sharp)
                                : Container()
                          ]))
                    ],
                  ),
                ))));
  }
}

class ItemInfo extends StatefulWidget {
  final String id;

  ItemInfo(this.id);

  @override
  _ItemInfoState createState() => _ItemInfoState();
}

class _ItemInfoState extends State<ItemInfo> {
  Map<String, dynamic> data;

  @override
  void initState() {
    super.initState();
    data = _coinData[widget.id];
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
        length: 5,
        child: Scaffold(
            appBar: AppBar(
                title: Text(data["name"], style: TextStyle(fontSize: 25.0)),

                //Graph title bar color

                backgroundColor: Color(0xff7f5a83),
                actions: [
                  Row(children: [
                    FadeInImage(
                      image: NetworkImage(
                          "https://static.coincap.io/assets/icons/${data["symbol"].toLowerCase()}@2x.png"),
                      placeholder: AssetImage("icon/platypus2.png"),
                      fadeInDuration: const Duration(milliseconds: 100),
                      height: 32.0,
                      width: 32.0,
                    ),
                    Text(" " + data["symbol"]),
                    Container(width: 5.0)
                  ])
                ]),
            body: ListView(physics: ClampingScrollPhysics(), children: [
              Container(
                  color: Color(0xff7f5a83),
                  child: TabBar(tabs: [
                    Tab(
                        icon: AutoSizeText("1D",
                            maxFontSize: 25.0,
                            style: TextStyle(
                                fontSize: 25.0, fontWeight: FontWeight.bold),
                            minFontSize: 0.0)),
                    Tab(
                        icon: AutoSizeText("1W",
                            maxFontSize: 25.0,
                            style: TextStyle(
                                fontSize: 25.0, fontWeight: FontWeight.bold),
                            minFontSize: 0.0)),
                    Tab(
                        icon: AutoSizeText("1M",
                            maxFontSize: 25.0,
                            style: TextStyle(
                                fontSize: 25.0, fontWeight: FontWeight.bold),
                            minFontSize: 0.0)),
                    Tab(
                        icon: AutoSizeText("6M",
                            maxFontSize: 25.0,
                            style: TextStyle(
                                fontSize: 25.0, fontWeight: FontWeight.bold),
                            minFontSize: 0.0)),
                    Tab(
                        icon: AutoSizeText("1Y",
                            maxFontSize: 25.0,
                            style: TextStyle(
                                fontSize: 25.0, fontWeight: FontWeight.bold),
                            minFontSize: 0.0))
                  ])),
              Container(height: 15.0),
              Container(
                  height: 200.0,
                  padding: EdgeInsets.only(right: 10.0),
                  child: TabBarView(
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        SimpleTimeSeriesChart(widget.id, 1, "m5"),
                        SimpleTimeSeriesChart(widget.id, 7, "m30"),
                        SimpleTimeSeriesChart(widget.id, 30, "h2"),
                        SimpleTimeSeriesChart(widget.id, 182, "h12"),
                        SimpleTimeSeriesChart(widget.id, 364, "d1")
                      ])),
              Container(height: 10.0),
              Row(children: [
                Expanded(child: Info("Rank", widget.id, "rank")),
              ]),
              Row(children: [
                Expanded(child: Info("Price", widget.id, "priceUsd")),
              ]),
              Row(children: [
                Expanded(child: Info("24h Change", widget.id, "changePercent24Hr")),
              ]),
            ])));
  }
}

class Info extends StatefulWidget {
  final String title, ticker, id;

  Info(this.title, this.ticker, this.id);

  @override
  _InfoState createState() => _InfoState();
}

class _InfoState extends State<Info> {
  dynamic value;

  ValueNotifier<num> coinNotif;

  Color textColor;

  Timer updateTimer;

  bool disp = false;

  Map<String, dynamic> data;

  void update() {
    if (data["priceUsd"].compareTo(coinNotif.value) > 0) {
      textColor = Colors.green;
    } else {
      textColor = Colors.red;
    }
    setState(() {});
    updateTimer?.cancel();
    updateTimer = Timer(Duration(milliseconds: 400), () {
      if (disp) {
        return;
      }
      setState(() {
        textColor = null;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.id == "priceUsd") {
      coinNotif = _valueNotifiers[widget.ticker];
      coinNotif.addListener(update);
    } else {
      textColor = Colors.white;
    }
    data = _coinData[widget.ticker];
  }

  @override
  void dispose() {
    super.dispose();
    if (widget.id == "priceUsd") {
      disp = true;
      coinNotif.removeListener(update);
    }
  }

  @override
  Widget build(BuildContext context) {
    dynamic value = data[widget.id];
    String text;
    if ((widget.id == "changePercent24Hr" && value == -1000000) ||
        value == null ||
        value == -1) {
      text = "N/A";
    } else {
      NumberFormat formatter;
      if (widget.id == "priceUsd") {
        formatter = NumberFormat.currency(
            symbol: _symbol,
            decimalDigits: value > 1
                ? value < 100000
                    ? 2
                    : 0
                : value > .000001
                    ? 6
                    : 7);
      } else if (widget.id == "marketCapUsd") {
        formatter = NumberFormat.currency(
            symbol: _symbol, decimalDigits: value > 1 ? 0 : 2);
      } else if (widget.id == "changePercent24Hr") {
        formatter = NumberFormat.currency(symbol: "", decimalDigits: 3);
      } else {
        formatter = NumberFormat.currency(symbol: "", decimalDigits: 0);
      }
      text = formatter.format(value);
    }
    if (widget.id == "changePercent24Hr" && value != -1000000) {
      text += "%";
      text = (value > 0 ? "+" : "") + text;
      textColor = value < 0
          ? Colors.red
          : value > 0
              ? Colors.green
              : Colors.white;
    }
    return Container(
        padding: EdgeInsets.only(top: 2.0, left: 2.0, right: 2.0),
        child: Card(
            child: Container(
                height: 60.0,
                color: Color(0xff7f5a83),
                padding: EdgeInsets.only(top: 10.0, bottom: 10.0),
                child: Column(children: [
                  Text(widget.title,
                      textAlign: TextAlign.left,
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  ConstrainedBox(
                    child: AutoSizeText(text,
                        minFontSize: 0,
                        maxFontSize: 17,
                        style: TextStyle(fontSize: 17, color: textColor),
                        maxLines: 1),
                    constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width / 2 - 8),
                  )
                ]))));
  }
}

class TimeSeriesPrice {
  DateTime time;
  double price;

  TimeSeriesPrice(this.time, this.price);
}

class SimpleTimeSeriesChart extends StatefulWidget {
  final String period, id;

  final int startTime;

  SimpleTimeSeriesChart(this.id, this.startTime, this.period);

  @override
  _SimpleTimeSeriesChartState createState() => _SimpleTimeSeriesChartState();
}

class _SimpleTimeSeriesChartState extends State<SimpleTimeSeriesChart> {
  List<TimeSeriesPrice> seriesList;
  double count = 0.0;
  double selectedPrice = -1.0;
  DateTime selectedTime;
  bool canLoad = true, loading = true;
  int base;
  num minVal, maxVal;

  @override
  void initState() {
    super.initState();
    DateTime now = DateTime.now();
    http
        .get(Uri.encodeFull(

            //Api key for the all coin

            "https://api.coincap.io/v2/assets/${widget.id}/history?interval=" +
                widget.period +
                "&start=" +
                now
                    .subtract(Duration(days: widget.startTime))
                    .millisecondsSinceEpoch
                    .toString() +
                "&end=" +
                now.millisecondsSinceEpoch.toString()))
        .then((value) {
      seriesList = createChart(json.decode(value.body), widget.id);
      setState(() {
        loading = false;
      });
      base = minVal >= 0 ? max(0, (-log(minVal) / log(10)).ceil() + 2) : 0;
      if (minVal <= 1.1 && minVal > .9) {
        base++;
      }
    });
  }

  Map<String, int> dataPerDay = {
    "m5": 288,
    "m30": 48,
    "h2": 12,
    "h12": 2,
    "d1": 1
  };

  Map<String, DateFormat> formatMap = {
    "m5": DateFormat("h꞉mm a"),
    "m30": DateFormat.MMMd(),
    "h2": DateFormat.MMMd(),
    "h12": DateFormat.MMMd(),
    "d1": DateFormat.MMMd(),
  };

  @override
  Widget build(BuildContext context) {
    bool hasData = seriesList != null &&
        seriesList.length > (widget.startTime * dataPerDay[widget.period] / 10);
    double dif, factor, visMax, visMin;
    DateFormat xFormatter = formatMap[widget.period];
    NumberFormat yFormatter = NumberFormat.currency(
        symbol: _symbol.toString().replaceAll("\.", ""),
        locale: "en_US",
        decimalDigits: base);
    if (!loading && hasData) {
      dif = (maxVal - minVal);
      factor = min(1, max(.2, dif / maxVal));
      visMin = max(0, minVal - dif * factor);
      visMax = visMin != 0 ? maxVal + dif * factor : maxVal + minVal;
    }
    return !loading && canLoad && hasData
        ? Container(
            width: 350.0 * MediaQuery.of(context).size.width / 375.0,
            height: 200.0,
            child: SfCartesianChart(
              series: [
                LineSeries<TimeSeriesPrice, DateTime>(
                    dataSource: seriesList,
                    xValueMapper: (TimeSeriesPrice s, _) => s.time,
                    yValueMapper: (TimeSeriesPrice s, _) => s.price,
                    animationDuration: 0,
                    color: Colors.black)//graph border color
              ],
              plotAreaBackgroundColor: Colors.transparent,
              primaryXAxis: DateTimeAxis(dateFormat: xFormatter),
              primaryYAxis: NumericAxis(
                  numberFormat: yFormatter,
                  decimalPlaces: base,
                  visibleMaximum: visMax,
                  visibleMinimum: visMin,
                  interval: (visMax - visMin) / 4.001),
              selectionGesture: ActivationMode.singleTap,
              selectionType: SelectionType.point,
              onAxisLabelRender: (a) {
                if (a.orientation == AxisOrientation.vertical) {
                  a.text = yFormatter.format(a.value);
                } else {
                  a.text = xFormatter
                      .format(DateTime.fromMillisecondsSinceEpoch(a.value));
                }
              },
              trackballBehavior: TrackballBehavior(
                  activationMode: ActivationMode.singleTap,
                  enable: true,
                  shouldAlwaysShow: true,
                  tooltipSettings: InteractiveTooltip(
                      color: Colors.black,
                      format: "point.x | point.y",
                      decimalPlaces: base)),
              onTrackballPositionChanging: (a) {
                var v = a.chartPointInfo.chartDataPoint;
                a.chartPointInfo.label =
                    "${xFormatter.format(v.x)} | ${yFormatter.format(v.y)}";
              },
            ))
        : canLoad && (hasData || loading)
            ? Container(
                height: 233.0,
                padding: EdgeInsets.only(left: 10.0, right: 10.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [CircularProgressIndicator()]))
            : Container(
                height: 233.0,
                child: Center(
                    child: Text("Sorry, this coin graph is not supported",
                        style: TextStyle(fontSize: 17.0))));
  }

  List<TimeSeriesPrice> createChart(Map<String, dynamic> info, String s) {
    List<TimeSeriesPrice> data = [];

    if (info != null && info.length > 1) {
      for (int i = 0; i < info["data"].length; i++) {
        num val = num.parse(info["data"][i]["priceUsd"]) * _exchangeRate;
        minVal = min(minVal ?? val, val);
        maxVal = max(maxVal ?? val, val);
        data.add(TimeSeriesPrice(
            DateTime.fromMillisecondsSinceEpoch(info["data"][i]["time"]), val));
      }
    } else {
      canLoad = false;
    }
    return data;
  }
}
