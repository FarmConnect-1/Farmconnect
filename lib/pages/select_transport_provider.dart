import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectTransportProviderPage extends StatefulWidget {
  final String productId;
  final String productName;

  const SelectTransportProviderPage({super.key, required this.productId, required this.productName});

  @override
  _SelectTransportProviderPageState createState() => _SelectTransportProviderPageState();
}

class _SelectTransportProviderPageState extends State<SelectTransportProviderPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Transport Provider'),
      ),
      body: FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('TransportProviders').get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Error loading transport providers.'));
          }

          List<QueryDocumentSnapshot> allTransporters = snapshot.data?.docs ?? [];

          if (allTransporters.isEmpty) {
            return const Center(child: Text('No transport providers found.'));
          }

          return ListView.builder(
            itemCount: allTransporters.length,
            itemBuilder: (context, index) {
              var transporter = allTransporters[index];
              String transporterId = transporter.id;
              String transporterName = transporter['name'] ?? 'Unknown';
              String contact = transporter['contact'] ?? 'No contact available';
              String vehicleType = transporter['vehicleType'] ?? 'Unknown';
              String location = transporter['location'] ?? 'Unknown';
              double pricePerKm = (transporter['pricePerKm'] as num).toDouble();

              return ListTile(
                title: Text(transporterName),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contact: $contact'),
                    Text('Vehicle: $vehicleType'),
                    Text('Location: $location'),
                    Text('Price per km: \$$pricePerKm'),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () async {
                    // Assign the selected transport provider to the product
                    await FirebaseFirestore.instance.collection('Products')
                        .doc(widget.productId)
                        .update({
                      'assignedTransporter': transporterId,
                    });

                    // Optionally: Notify user of success
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Transport provider selected: $transporterName')),
                    );

                    // Navigate back to the BidHistoryPage after selecting the transport provider
                    Navigator.pop(context); // Pop this page
                  },
                  child: const Text('Select'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
