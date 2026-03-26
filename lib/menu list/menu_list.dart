// ignore_for_file: prefer_const_constructors, avoid_print

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../global.dart';
import '../model/app_responsive.dart';
import '../model/constant.dart';
import '../orders/place_order.dart';

class MenuList extends StatefulWidget {
  final dynamic mediaQueryData;

  const MenuList({super.key, required this.mediaQueryData});

  @override
  State<MenuList> createState() => _MenuListState();
}

class _MenuListState extends State<MenuList> {
  final ScrollController controllerOne = ScrollController();

  @override
  Widget build(BuildContext context) {
    final mediaQueryData = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Theme(
        data: Theme.of(context).copyWith(
          scrollbarTheme: ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(Colors.black54),
            crossAxisMargin: 3,
          ),
        ),
        child: Scrollbar(
          controller: controllerOne,
          thumbVisibility: true,
          trackVisibility: true,
          child: Stack(
            children: [
              footerImage(mediaQueryData),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('vendors')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, vendorsSnapshot) {
                  if (vendorsSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('foods')
                        .orderBy('title')
                        .snapshots(),
                    builder: (context, foodsSnapshot) {
                      if (foodsSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (vendorsSnapshot.hasError || foodsSnapshot.hasError) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Unable to load vendors and foods right now.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      final vendorDocs = vendorsSnapshot.data?.docs ?? [];
                      final foodDocs = foodsSnapshot.data?.docs ?? [];
                      final sections =
                          _buildVendorSections(vendorDocs, foodDocs);

                      if (sections.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No vendors or foods available yet.'),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: controllerOne,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppResponsive.isMobile(context) ? 10 : 16,
                          vertical: 12,
                        ),
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final section = sections[index];
                          return _VendorSection(
                            title: section.vendorName,
                            description: section.description,
                            foods: section.foods,
                            mediaQueryData: widget.mediaQueryData,
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_VendorFoodSection> _buildVendorSections(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> vendorDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> foodDocs,
  ) {
    final vendorMeta = <String, _VendorMeta>{};
    for (final doc in vendorDocs) {
      final data = doc.data();
      final vendorName = (data['name'] ?? '').toString().trim();
      final description = (data['description'] ?? '').toString().trim();
      vendorMeta[doc.id] = _VendorMeta(
        id: doc.id,
        name: vendorName.isNotEmpty ? vendorName : 'Vendor',
        description: description,
        isActive: data['isActive'] != false,
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final doc in foodDocs) {
      final data = doc.data();
      final vendorId = (data['vendorId'] ?? '').toString().trim();
      final vendorName = (data['vendorName'] ?? '').toString().trim();
      final key = vendorId.isNotEmpty ? vendorId : vendorName;
      grouped.putIfAbsent(key, () => []).add({
        ...data,
        'docId': doc.id,
      });
    }

    final sections = <_VendorFoodSection>[];
    for (final entry in grouped.entries) {
      final meta = vendorMeta[entry.key];
      final foods = entry.value;
      foods.sort(
        (a, b) => (a['title']?.toString() ?? '')
            .compareTo(b['title']?.toString() ?? ''),
      );
      sections.add(
        _VendorFoodSection(
          vendorName: meta?.name ?? _fallbackVendorName(foods),
          description: meta?.description ?? '',
          foods: foods,
          sortKey: meta?.name ?? _fallbackVendorName(foods),
          isActive: meta?.isActive ?? true,
        ),
      );
    }

    sections.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return sections.where((section) => section.isActive).toList();
  }

  String _fallbackVendorName(List<Map<String, dynamic>> foods) {
    for (final food in foods) {
      final name = (food['vendorName'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
    }
    return 'Unassigned vendor';
  }

  ImageFiltered footerImage(MediaQueryData mediaQueryData) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
      child: Container(
        width: mediaQueryData.size.width,
        height: mediaQueryData.size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            filterQuality: FilterQuality.low,
            colorFilter: ColorFilter.mode(Colors.white12, BlendMode.color),
            fit: BoxFit.fill,
            image: AssetImage('assets/banners/banner2.jpg'),
          ),
        ),
      ),
    );
  }
}

class _VendorSection extends StatelessWidget {
  const _VendorSection({
    required this.title,
    required this.description,
    required this.foods,
    required this.mediaQueryData,
  });

  final String title;
  final String description;
  final List<Map<String, dynamic>> foods;
  final dynamic mediaQueryData;

  @override
  Widget build(BuildContext context) {
    final cardWidth = AppResponsive.isDesktop(context)
        ? 240.0
        : AppResponsive.isTablet(context)
            ? 220.0
            : 170.0;

    return Card(
      elevation: 6,
      color: Colors.white.withValues(alpha: 0.86),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: foods
                  .map(
                    (food) => SizedBox(
                      width: cardWidth,
                      child: _MenuFoodCard(
                        data: food,
                        mediaQueryData: mediaQueryData,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuFoodCard extends StatelessWidget {
  const _MenuFoodCard({
    required this.data,
    required this.mediaQueryData,
  });

  final Map<String, dynamic> data;
  final dynamic mediaQueryData;

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? 'Food';
    final subtitle = data['subtitle']?.toString() ?? '';
    final category = data['category']?.toString() ?? '';
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final price = _displayPrice(data['price']);

    return GestureDetector(
      onTap: () {
        showDialog(
          barrierDismissible: finalOrderId4 != null ? true : false,
          context: context,
          builder: (context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                width: double.infinity,
                height: finalOrderId4 != null
                    ? 200
                    : MediaQuery.of(context).size.height / 1.2,
                padding: const EdgeInsets.only(top: 16),
                child: finalOrderId4 == null
                    ? PlaceOdrer(
                        imagePath: imageUrl,
                        foodName: title,
                        imagePrice: price,
                        foodId: data['docId']?.toString() ?? '',
                        vendorId: data['vendorId']?.toString() ?? '',
                        vendorName: data['vendorName']?.toString() ?? '',
                        category: category,
                        description: data['description']?.toString() ?? '',
                      )
                    : Center(
                        child: Text(
                          textAlign: TextAlign.center,
                          'Your orders are pending. Kindly wait to be served\nThank You.',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
      child: Card(
        elevation: 8,
        color: Colors.white12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: imageUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: MenuListStyle.menuName,
              ),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (category.isNotEmpty)
                    Chip(
                      label: Text(category),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(
                    label: Text('GHS $price'),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _displayPrice(dynamic raw) {
    if (raw is num) {
      return raw.toStringAsFixed(2);
    }
    return raw?.toString() ?? '0.00';
  }
}

class _VendorFoodSection {
  const _VendorFoodSection({
    required this.vendorName,
    required this.description,
    required this.foods,
    required this.sortKey,
    required this.isActive,
  });

  final String vendorName;
  final String description;
  final List<Map<String, dynamic>> foods;
  final String sortKey;
  final bool isActive;
}

class _VendorMeta {
  const _VendorMeta({
    required this.id,
    required this.name,
    required this.description,
    required this.isActive,
  });

  final String id;
  final String name;
  final String description;
  final bool isActive;
}
