import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mywallet/widgets/chart.dart';
import 'package:mywallet/widgets/new_transaction.dart';
import 'package:mywallet/widgets/transaction_list.dart';
import 'package:mywallet/models/transaction.dart';

import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My Wallet',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        accentColor: Colors.amber,
        errorColor: Colors.red,
        fontFamily: 'OpenSans',
        textTheme: TextTheme(
          titleMedium: TextStyle(
            fontFamily: 'OpenSans',
            fontWeight: FontWeight.w700,
            color: Colors.deepPurple,
          ),
        ),
      ),
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  //late String titleInput;
  List<Transaction> _userTransactions = [];

  List<Transaction> get _recentTransactions {
    return _userTransactions.where((tx) {
      return tx.date.isAfter(
        DateTime.now().subtract(
          Duration(days: 7),
        ),
      );
    }).toList();
  }

  Future<void> fetchTransactions() async {
    setState(() {
      isLoading = true;
    });
    final url = Uri.https(
        'wallet-e5e68-default-rtdb.firebaseio.com', '/transactions.json');
    try {
      final response = await http.get(url);
      setState(() {
        isLoading = false;
      });

      final extractedData = jsonDecode(response.body) as Map<String, dynamic>;
      final List<Transaction> tempList = [];
      extractedData.forEach((tId, tData) {
        print('Doone');
        tempList.add(
          Transaction(
            id: tId,
            title: tData['title'],
            amount: tData['amount'],
            date: DateTime.parse(tData['date']),
          ),
        );
      });
      setState(() {
        _userTransactions = tempList;
      });
    } catch (error) {
      throw error;
    }
  }

  Future<void> _addNewTransaction(
      String txtitle, double txamount, DateTime d) async {
    var url = Uri.https(
        'wallet-e5e68-default-rtdb.firebaseio.com', '/transactions.json');
    try {
      final value = await http.post(url,
          body: jsonEncode({
            "title": txtitle,
            "amount": txamount,
            "date": d.toString(),
          }));
      final tx = Transaction(
        title: txtitle,
        amount: txamount,
        date: d,
        id: jsonDecode(value.body)['name'],
      );

      setState(() {
        _userTransactions.add(tx);
      });
    } catch (error) {
      print(error);
      throw error;
    }
  }

  void _deleteTransaction(String id) {
    var url = Uri.https(
        'wallet-e5e68-default-rtdb.firebaseio.com', '/transactions/$id.json');

    final txIndex = _userTransactions.indexWhere((tx) => tx.id == id);
    final Transaction txProd = _userTransactions[txIndex];

    _userTransactions.removeAt(txIndex);

    http.delete(url).catchError((error) {
      _userTransactions.insert(txIndex, txProd);
    });

    setState(() {
      _userTransactions.removeWhere((tx) {
        return tx.id == id;
      });
    });
  }

  void _startAddNewTransaction(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      builder: (bCtx) {
        return GestureDetector(
          child: NewTransaction(_addNewTransaction),
          onTap: () {},
          behavior: HitTestBehavior.opaque,
        );
      },
    );
  }

  bool isLoading = false;
  bool _showChart = false;

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final PreferredSizeWidget appBar = Platform.isIOS
        ? CupertinoNavigationBar(
            middle: Text('My Wallet'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  child: Icon(CupertinoIcons.add),
                  onTap: () => _startAddNewTransaction(context),
                )
              ],
            ),
          ) as PreferredSizeWidget
        : AppBar(
            title: Text(
              'My Wallet',
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () => fetchTransactions(),
                icon: Icon(Icons.refresh),
              ),
            ],
          );

    final chartContainer = Container(
        height: (MediaQuery.of(context).size.height -
                appBar.preferredSize.height -
                MediaQuery.of(context).padding.top) *
            0.6,
        child: Chart(_recentTransactions));
    final listContainer = Container(
        height: (MediaQuery.of(context).size.height -
                appBar.preferredSize.height -
                MediaQuery.of(context).padding.top) *
            0.7,
        child: TransactionList(_userTransactions, _deleteTransaction, isLoading,
            fetchTransactions));
    // SafeArea widget for managing space on iOS
    final pageBody = SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isLandscape)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Show Chart',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Switch.adaptive(
                      activeColor: Theme.of(context).accentColor,
                      value: _showChart,
                      onChanged: (val) {
                        setState(() {
                          _showChart = val;
                        });
                      }),
                ],
              ),
            if (!isLandscape)
              Container(
                  height: (MediaQuery.of(context).size.height -
                          appBar.preferredSize.height -
                          MediaQuery.of(context).padding.top) *
                      0.3,
                  child: Chart(_recentTransactions)),
            if (!isLandscape) listContainer,
            if (isLandscape)
              _showChart == true ? chartContainer : listContainer,
          ],
        ),
      ),
    );

    return Platform.isIOS
        ? CupertinoPageScaffold(child: pageBody)
        : Scaffold(
            appBar: appBar,
            body: pageBody,
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: Platform.isIOS
                ? Container()
                : FloatingActionButton(
                    child: Icon(Icons.add),
                    onPressed: () => _startAddNewTransaction(context),
                  ),
          );
  }
}
