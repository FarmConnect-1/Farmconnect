import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  // Fetch orders based on the authenticated user
  Future<QuerySnapshot?> _fetchOrders() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      return FirebaseFirestore.instance
          .collection('Orders')
          .where('retailerId', isEqualTo: user.uid)
          .get();
    }
    return null; // Return null if the user is not authenticated
  }

  // Fetch bid details using bidId from the Bids collection
  Future<DocumentSnapshot?> _fetchBidDetails(String bidId) async {
    if (bidId.isNotEmpty) {
      return FirebaseFirestore.instance.collection('Bids').doc(bidId).get();
    }
    return null; // Return null if bidId is empty
  }

  // Fetch retailer name using retailerId
  Future<String> _fetchRetailerName(String retailerId) async {
    try {
      DocumentSnapshot retailerSnapshot =
      await FirebaseFirestore.instance.collection('Users').doc(retailerId).get();
      if (retailerSnapshot.exists) {
        Map<String, dynamic> data = retailerSnapshot.data() as Map<String, dynamic>;
        return data['username'] ?? 'Unknown Retailer';
      }
    } catch (e) {
      print('Error fetching retailer name: $e');
    }
    return 'Unknown Retailer';
  }

  // Generate Invoice as a PDF
  Future<void> _generateInvoice({
    required BuildContext context,
    required String farmerName,
    required String retailerName,
    required String productName,
    required double bidAmount,
    required int quantity,
    required double totalAmount,
    required double amountPaid,
    required double remainingAmount,
    required String orderId,
    required String orderDate,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Invoice', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('Order Date: $orderDate'),
            pw.Text('Order ID: $orderId'),
            pw.SizedBox(height: 20),
            pw.Text('From: $farmerName'),
            pw.SizedBox(height: 10),
            pw.Text('To: $retailerName'),
            pw.SizedBox(height: 20),
            pw.Text('Product Details:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text('Product Name: $productName'),
            pw.Text('Quantity: $quantity'),
            pw.Text('Price: ₹${bidAmount.toStringAsFixed(2)}'),
            pw.Text('Total Amount: ₹${totalAmount.toStringAsFixed(2)}'),
            pw.Text('Amount Paid: ₹${amountPaid.toStringAsFixed(2)}'),
            pw.Text('Remaining Amount: ₹${remainingAmount.toStringAsFixed(2)}'),
            pw.Divider(),
            pw.Text('Thank you for your business!'),
          ],
        ),
      ),
    );

    try {
      // Get the Downloads directory
      final directory = Directory('/storage/emulated/0/Download'); // Path to Downloads folder
      if (!directory.existsSync()) {
        throw Exception("Downloads folder not found");
      }

      // Save the file in the Downloads directory
      final file = File('${directory.path}/invoice_$orderId.pdf');
      await file.writeAsBytes(await pdf.save());

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Invoice saved in Downloads: ${file.path}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to save invoice: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Order History'),
        ),
        body: Container(
          color: const Color(0xFF0097b2),
          child: FutureBuilder<QuerySnapshot?>(
            future: _fetchOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return const Center(child: Text('Error loading orders'));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No orders found'));
              }

              return ListView(
                children: snapshot.data!.docs.map((DocumentSnapshot document) {
                  Map<String, dynamic> order = document.data() as Map<String, dynamic>;

                  String productId = order['productID'] ?? '';
                  String bidId = order['bidId'] ?? '';
                  String farmerId = order['farmerId'] ?? '';
                  String retailerId = order['retailerId'] ?? '';
                  String orderId = document.id;
                  Timestamp timestamp = order['orderDate'] ?? Timestamp.now();
                  String orderDate = timestamp.toDate().toString(); // Converts to DateTime and formats as String

                  // Fetch product and farmer information
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('Products').doc(productId).get(),
                    builder: (context, productSnapshot) {
                      if (productSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (productSnapshot.hasError || !productSnapshot.hasData || !productSnapshot.data!.exists) {
                        return const Center(child: Text('Error fetching product details'));
                      }

                      Map<String, dynamic> productData = productSnapshot.data!.data() as Map<String, dynamic>;
                      String productName = productData['productName'] ?? 'Unknown Product';

                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('Users').doc(farmerId).get(),
                        builder: (context, farmerSnapshot) {
                          if (farmerSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (farmerSnapshot.hasError || !farmerSnapshot.hasData || !farmerSnapshot.data!.exists) {
                            return const Center(child: Text('Error fetching farmer details'));
                          }

                          Map<String, dynamic> farmerData = farmerSnapshot.data!.data() as Map<String, dynamic>;
                          String farmerName = farmerData['username'] ?? 'Unknown Farmer';

                          return FutureBuilder<String>(
                            future: _fetchRetailerName(retailerId),
                            builder: (context, retailerSnapshot) {
                              if (retailerSnapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (retailerSnapshot.hasError || !retailerSnapshot.hasData) {
                                return const Center(child: Text('Error fetching retailer name'));
                              }

                              String retailerName = retailerSnapshot.data!;

                              // Fetch bid details using bidId
                              return FutureBuilder<DocumentSnapshot?>(
                                future: _fetchBidDetails(bidId),
                                builder: (context, bidSnapshot) {
                                  if (bidSnapshot.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  if (bidSnapshot.hasError || !bidSnapshot.hasData || !bidSnapshot.data!.exists) {
                                    return const Center(child: Text('Error fetching bid details'));
                                  }

                                  Map<String, dynamic> bidData = bidSnapshot.data!.data() as Map<String, dynamic>;
                                  double bidAmount = (bidData['bidAmount'] ?? 0).toDouble();
                                  int quantity = bidData['quantity'] ?? 0;
                                  double totalAmount = bidAmount * quantity;
                                  double amountPaid = (order['amountPaid'] ?? 0).toDouble();
                                  double remainingAmount = totalAmount - amountPaid;

                                  return Card(
                                    margin: const EdgeInsets.all(10),
                                    elevation: 5,
                                    child: Column(
                                      children: [
                                        ListTile(
                                          title: Text(
                                            productName,
                                            style: const TextStyle(fontSize: 24,fontWeight: FontWeight.bold),
                                          ),
                                          subtitle: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              buildProductDetail( 'Farmer', '$farmerName'),
                                              buildProductDetail( 'Bid Amount', '₹${bidAmount.toStringAsFixed(2)}'),
                                              buildProductDetail( 'Quantity', '$quantity'),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Padding(padding: EdgeInsets.only(left: 5,right: 5)),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: (){},
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  padding: EdgeInsets.symmetric(vertical: 16),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                child: Text(
                                                  'Select Transporter',
                                                  style: TextStyle(fontSize: 18),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  _generateInvoice(
                                                    context: context,
                                                    farmerName: farmerName,
                                                    retailerName: retailerName,
                                                    productName: productName,
                                                    bidAmount: bidAmount,
                                                    quantity: quantity,
                                                    totalAmount: totalAmount,
                                                    amountPaid: amountPaid,
                                                    remainingAmount: remainingAmount,
                                                    orderId: orderId,
                                                    orderDate: orderDate,
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange,
                                                  padding: EdgeInsets.symmetric(vertical: 16),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                ),
                                                child: Text(
                                                  "Get Invoice",
                                                  style: TextStyle(fontSize: 18),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 10),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        )
    );
  }
  Widget buildProductDetail(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}