import 'dart:developer';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:my_app/utils/helperfunctions.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slider_button/slider_button.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  var connector = WalletConnect(
      bridge: 'https://bridge.walletconnect.org',
      clientMeta: const PeerMeta(
          name: 'My App',
          description: 'Hello world',
          url: 'https://deltalabsjsc.com/',
          icons: [
            'https://deltalabsjsc.com/wp-content/uploads/2022/05/Logo-Delta-Labs-Footer.png'
          ]));

  var _session, _uri, _signature, _ethBalance, _tokenBalance;
  bool _loading = false;

  final Web3Client _web3client = Web3Client(
      'https://data-seed-prebsc-1-s1.binance.org:8545/', http.Client());
  late DeployedContract contract;

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  final FocusNode amountFocusNode = FocusNode();
  final TextEditingController amountController = TextEditingController();

  bool isNumeric(String s) {
    if (s == null) {
      return false;
    }
    return double.tryParse(s) != null;
  }
  String? amountValidator(String? val) {
    if (!isNumeric(val!)) return "Add integer amount.";
    return null;
  }

  Future<void> getEthBalance(String from) async {
    EthereumAddress address = EthereumAddress.fromHex(from);
    EtherAmount etherAmount = await _web3client.getBalance(address);
    setState(() {
      _ethBalance = etherAmount.getValueInUnit(EtherUnit.ether);
    });
  }

  Future<void> getTokenBalance(String from) async {
    EthereumAddress address = EthereumAddress.fromHex(from);
    ContractFunction _balanceFunction() => contract.function('balanceOf');
    final response = await _web3client.call(contract: contract, function: _balanceFunction(), params: [address]);
    setState(() {
      _tokenBalance = BigInt.parse(response.first.toString()) / BigInt.from(10).pow(18);
    });
  }

  Future<void> refreshBalance() async {
    await getEthBalance(_session.accounts[0]);
    await getTokenBalance(_session.accounts[0]);
    amountController.text = "";
  } 

  loginUsingMetamask(BuildContext context) async {
    if (!connector.connected) {
      try {
        var session = await connector.createSession(onDisplayUri: (uri) async {
          _uri = uri;
          await launchUrlString(uri, mode: LaunchMode.externalApplication);
        });

        const abiString =
            '[{"inputs":[{"internalType":"address","name":"account","type":"address"}],"name":"balanceOf","outputs":[{"internalType":"uint256","name":"","type":"uint256"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"amount","type":"uint256"}],"name":"mint","outputs":[],"stateMutability":"nonpayable","type":"function"}]';
        final ContractAbi abi = ContractAbi.fromJson(abiString, 'BUSD');
        String contractAddress = "0x280b2e8b297e15467bc1929941b5439ec67fc145";
        contract = DeployedContract(abi, EthereumAddress.fromHex(contractAddress));

        await getEthBalance(session.accounts[0]);
        await getTokenBalance(session.accounts[0]);
        
        print(session.accounts[0]);
        print(session.chainId);
        setState(() {
          _session = session;
        });
      } catch (exp) {
        print(exp);
      }
    }
  }

  signMessageWithMetamask(BuildContext context, String message) async {
    print(connector);
    if (connector.connected) {
      try {
        print(context);
        print("Message received");
        print(message);

        EthereumWalletConnectProvider provider =
            EthereumWalletConnectProvider(connector);
        launchUrlString(_uri, mode: LaunchMode.externalApplication);
        print(_session.accounts[0]);
        var signature = await provider.sign(
            message: message, address: _session.accounts[0]);
        print(signature);
        setState(() {
          _signature = signature;
        });
      } catch (exp) {
        print("Error while signing transaction");
        print(exp);
      }
    }
  }

  mintToken() async {
    if (connector.connected) {
      try {
        if (formKey.currentState!.validate()) {
          amountFocusNode.unfocus();
          
          EthereumAddress toAddress = EthereumAddress.fromHex(
              '0xDDfF63db2915e932c8C7F3Dd271Dbe91a6529E8A');
          BigInt amount =
              BigInt.from(double.parse(amountController.text) * pow(10, 18));

          Uint8List data =
              contract.function('mint').encodeCall([toAddress, amount]);

          EthereumWalletConnectProvider provider =
              EthereumWalletConnectProvider(connector);
          launchUrlString(_uri, mode: LaunchMode.externalApplication);
          var transaction = await provider.sendTransaction(
            from: _session.accounts[0],
            to: '0x280b2e8B297E15467bC1929941b5439eC67fC145',
            gas: 200000,
            data: data,
          );

          print(transaction);
        }
      } catch (exp) {
        print("Error while signing transaction");
        print(exp);
      }
    }
  }

  getNetworkName(chainId) {
    switch (chainId) {
      case 1:
        return 'Ethereum Mainnet';
      case 3:
        return 'Ropsten Testnet';
      case 4:
        return 'Rinkeby Testnet';
      case 5:
        return 'Goreli Testnet';
      case 42:
        return 'Kovan Testnet';
      case 56:
        return 'BSC Mainnet';
      case 97:
        return 'BSC Testnet';
      case 137:
        return 'Polygon Mainnet';
      case 80001:
        return 'Mumbai Testnet';
      default:
        return 'Unknown Chain';
    }
  }

  @override
  Widget build(BuildContext context) {
    connector.on(
        'connect',
        (session) => setState(
              () {
                _session = _session;
              },
            ));
    connector.on(
        'session_update',
        (payload) => setState(() {
              _session = payload;
              print(_session.accounts[0]);
              print(_session.chainId);
            }));
    connector.on(
        'disconnect',
        (payload) => setState(() {
              _session = null;
            }));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Login Page'),
      ),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.bottomCenter,  
              child: Image.asset(
                'assets/images/main_page_image.png',
                height: 200,
                fit: BoxFit.fitHeight,
              ),
            ),
            (_session != null)
                ? Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
                          style: GoogleFonts.merriweather(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          '${_session.accounts[0]}',
                          style: GoogleFonts.inconsolata(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'Chain: ',
                              style: GoogleFonts.merriweather(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              getNetworkName(_session.chainId),
                              style: GoogleFonts.inconsolata(fontSize: 16),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: (() => refreshBalance()),
                              style: ElevatedButton.styleFrom(
                                primary: Colors.grey,
                                padding: const EdgeInsets.all(7),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Wrap(
                                  children: const <Widget>[
                                  Icon(
                                      Icons.refresh,
                                      color: Colors.white,
                                      size: 14.0,
                                  ),
                                  SizedBox(
                                      width: 5.0,
                                  ),
                                  Text("Refresh", style:TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          _ethBalance != null
                              ? '\nBalance: ${_ethBalance.toString()} BNB'
                              : '',
                          style: GoogleFonts.inconsolata(fontSize: 16),
                        ),
                        Text(
                          _tokenBalance != null
                              ? '\nToken Balance: ${_tokenBalance.toString()} BUSD'
                              : '',
                          style: GoogleFonts.inconsolata(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        (_session.chainId != 97)
                            ? Row(
                                children: const [
                                  Icon(Icons.warning,
                                      color: Colors.redAccent, size: 15),
                                  Text('Network not supported. Switch to '),
                                  Text(
                                    'Mumbai Testnet',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold),
                                  )
                                ],
                              )
                            : (_signature == null)
                                ? Form(
                                    key: formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        TextFormField(
                                          controller: amountController,
                                          focusNode: amountFocusNode,
                                          decoration: InputDecoration(
                                            border: InputBorder.none,
                                            enabled: true,
                                            filled: true,
                                            fillColor: Colors.black12
                                                .withOpacity(0.05),
                                            hintText: 'Amount',
                                            hintStyle: const TextStyle(
                                              color: Colors.black12,
                                            ),
                                          ),
                                          cursorColor: Colors.black,
                                          validator: amountValidator,
                                        ),
                                        const SizedBox(height: 20),
                                        Container(
                                          alignment: Alignment.center,
                                          child: ElevatedButton(
                                              // onPressed: () =>
                                              //     signMessageWithMetamask(
                                              //         context,
                                              //         generateSessionMessage(
                                              //             _session.accounts[0])),
                                              onPressed: (() => mintToken()),
                                              child: const Text('Mint Token')),
                                        )
                                      ],
                                    ))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "Signature: ",
                                            style: GoogleFonts.merriweather(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16),
                                          ),
                                          Text(
                                              truncateString(
                                                  _signature.toString(), 4, 2),
                                              style: GoogleFonts.inconsolata(
                                                  fontSize: 16))
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      SliderButton(
                                        action: () async {
                                          // TODO: Navigate to main page
                                        },
                                        label: const Text('Slide to login'),
                                        icon: const Icon(Icons.check),
                                      )
                                    ],
                                  )
                      ],
                    ))
                : ElevatedButton(
                    onPressed: () => loginUsingMetamask(context),
                    child: const Text("Connect with Metamask"))
          ],
        ),
      ),
    );
  }
}
