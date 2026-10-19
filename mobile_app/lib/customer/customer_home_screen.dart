// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import '../booking/booking_screens.dart';
import '../discovery/discovery_repository.dart';
import '../domain/vehicle_listing.dart';
import '../financial/financial_screens.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    this.onSwitchToOwner,
    this.onSwitchToDriver,
  });

  final VoidCallback? onSwitchToOwner;
  final VoidCallback? onSwitchToDriver;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _currentTab = 0;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  String _selectedLocation = 'Abuja, Nigeria';
  final Set<String> _favorites = {'demo-tesla-y', 'demo-mercedes-g'};
  final DiscoveryRepository _repository = DiscoveryRepository();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = const [
    {'name': 'All', 'icon': Icons.directions_car_rounded},
    {'name': 'SUV', 'icon': Icons.airport_shuttle_rounded},
    {'name': 'Luxury', 'icon': Icons.diamond_outlined},
    {'name': 'Electric', 'icon': Icons.bolt_rounded},
    {'name': 'Sedan', 'icon': Icons.drive_eta_rounded},
    {'name': 'Compact', 'icon': Icons.electric_car_rounded},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFavorite(String vehicleId) {
    setState(() {
      if (_favorites.contains(vehicleId)) {
        _favorites.remove(vehicleId);
      } else {
        _favorites.add(vehicleId);
      }
    });
  }

  void _showLocationPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Pickup Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...[
                'Abuja, Nigeria',
                'Maitama, Abuja',
                'Wuse II, Abuja',
                'Central Business District',
                'Airport Road (Nnamdi Azikiwe)',
                'New York, USA',
              ].map((loc) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.location_on_rounded,
                      color: _selectedLocation == loc
                          ? const Color(0xFF13382C)
                          : Colors.grey.shade400,
                    ),
                    title: Text(
                      loc,
                      style: TextStyle(
                        fontWeight: _selectedLocation == loc
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: _selectedLocation == loc
                            ? const Color(0xFF13382C)
                            : Colors.black87,
                      ),
                    ),
                    trailing: _selectedLocation == loc
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF13382C))
                        : null,
                    onTap: () {
                      setState(() => _selectedLocation = loc);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter Vehicles',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategory = 'All';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Reset',
                          style: TextStyle(color: Color(0xFF13382C))),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Category',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final name = c['name'] as String;
                    final active = _selectedCategory == name;
                    return ChoiceChip(
                      label: Text(name),
                      selected: active,
                      selectedColor: const Color(0xFF13382C),
                      labelStyle: TextStyle(
                        color: active ? Colors.white : Colors.black87,
                        fontWeight:
                            active ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (val) {
                        setModalState(() {
                          _selectedCategory = name;
                        });
                        setState(() {
                          _selectedCategory = name;
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF13382C),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showNotificationSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star_rounded,
                      color: Color(0xFF13382C)),
                ),
                title: const Text('Welcome to Mota Abuja',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Explore premium vehicles with self-drive and chauffeur options.'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F5ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Color(0xFF13382C)),
                ),
                title: const Text('New Electric Fleet Added',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    'Tesla Model Y & Porsche Taycan are now available in Maitama.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      body: SafeArea(
        child: IndexedStack(
          index: _currentTab,
          children: [
            _buildHomeTab(),
            _buildExploreTab(),
            _buildBookingsTab(),
            _buildProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeTab() {
    return StreamBuilder<List<VehicleListing>>(
      stream: _repository.approved(),
      builder: (context, snapshot) {
        final listings = snapshot.data ?? demoVehicles;
        final filtered = filterApproved(
          listings,
          DiscoveryFilters(
            keyword: _searchQuery,
            category: _selectedCategory == 'All' ? null : _selectedCategory,
          ),
        );

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopHeader(),
                    const SizedBox(height: 20),
                    _buildHeroHeading(),
                    const SizedBox(height: 20),
                    _buildSearchBar(),
                    const SizedBox(height: 18),
                    _buildCategoryPills(),
                    const SizedBox(height: 20),
                    _buildPromoBanner(),
                    const SizedBox(height: 24),
                    _buildSectionHeader('Popular Cars'),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: filtered.isEmpty
                  ? SliverToBoxAdapter(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        alignment: Alignment.center,
                        child: Text(
                          'No vehicles match your criteria.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  : SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.76,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final vehicle = filtered[index];
                          return _buildCarCard(vehicle);
                        },
                        childCount: filtered.length,
                      ),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 30)),
          ],
        );
      },
    );
  }

  Widget _buildTopHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: _showLocationPicker,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on_rounded,
                    color: Color(0xFF13382C), size: 20),
                const SizedBox(width: 6),
                Text(
                  _selectedLocation,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF4B5563), size: 18),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _showNotificationSheet,
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        size: 20, color: Color(0xFF374151)),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () => setState(() => _currentTab = 3),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF13382C),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'AO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroHeading() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good afternoon.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF13382C),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Rent a Car\nYour Way',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -0.8,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Premium cars for every journey,\nat the best price.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF13382C),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF13382C).withOpacity(0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 22),
            onPressed: () => setState(() => _currentTab = 1),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: const InputDecoration(
                hintText: 'Search by car, location or brand...',
                hintStyle: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF9CA3AF),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Color(0xFF9CA3AF)),
            ),
          const SizedBox(width: 6),
          Container(
            height: 24,
            width: 1,
            color: const Color(0xFFE5E7EB),
          ),
          const SizedBox(width: 6),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.tune_rounded,
                color: Color(0xFF13382C), size: 20),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPills() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final name = cat['name'] as String;
          final icon = cat['icon'] as IconData;
          final isSelected = _selectedCategory == name;

          return InkWell(
            onTap: () => setState(() => _selectedCategory = name),
            borderRadius: BorderRadius.circular(25),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isSelected ? const Color(0xFF13382C) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF13382C)
                      : const Color(0xFFE5E7EB),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF13382C).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 17,
                    color: isSelected ? Colors.white : const Color(0xFF4B5563),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      height: 185,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=1000&q=80',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF17362C),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    const Color(0xFF0C241D).withOpacity(0.92),
                    const Color(0xFF0C241D).withOpacity(0.60),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.65, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'EXPLORE MORE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF6EE7B7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Premium Rides\nFor Real Journeys',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      height: 1.15,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'From city drives to\nweekend getaways.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => setState(() => _currentTab = 1),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Book Now',
                            style: TextStyle(
                              color: Color(0xFF13382C),
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 13,
                            color: Color(0xFF13382C),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        InkWell(
          onTap: () => setState(() => _currentTab = 1),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'See all',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: Colors.grey.shade600),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCarCard(VehicleListing vehicle) {
    final isFav = _favorites.contains(vehicle.id);
    final rateInDollars = (vehicle.dailyRateNgn / 1000).round();

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LuxuryVehicleDetailScreen(
            vehicle: vehicle,
            isFavorite: isFav,
            onToggleFavorite: () => _toggleFavorite(vehicle.id),
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFECEEF1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 1.45,
                    child: Container(
                      color: const Color(0xFFF3F4F6),
                      child: vehicle.photoPaths.isNotEmpty
                          ? Image.network(
                              vehicle.photoPaths.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.directions_car_rounded,
                                    size: 40, color: Colors.grey.shade400),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.directions_car_rounded,
                                  size: 40, color: Colors.grey.shade400),
                            ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => _toggleFavorite(vehicle.id),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 16,
                        color: isFav
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.make} ${vehicle.model}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 3),
                  RichText(
                    text: TextSpan(
                      text: '\$$rateInDollars ',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                      children: [
                        TextSpan(
                          text: '/ day',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.people_alt_outlined,
                          size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Text(
                        '${vehicle.seats} Seats',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        vehicle.fuelType == 'Electric'
                            ? Icons.bolt_rounded
                            : Icons.local_gas_station_outlined,
                        size: 13,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        vehicle.fuelType,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        title: const Text('Explore Vehicles',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: StreamBuilder<List<VehicleListing>>(
        stream: _repository.approved(),
        builder: (context, snapshot) {
          final listings = snapshot.data ?? demoVehicles;
          final filtered = filterApproved(
            listings,
            DiscoveryFilters(
              keyword: _searchQuery,
              category: _selectedCategory == 'All' ? null : _selectedCategory,
            ),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildSearchBar(),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, bottom: 12),
                child: _buildCategoryPills(),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final v = filtered[index];
                    final isFav = _favorites.contains(v.id);
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LuxuryVehicleDetailScreen(
                            vehicle: v,
                            isFavorite: isFav,
                            onToggleFavorite: () => _toggleFavorite(v.id),
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 100,
                                height: 75,
                                child: v.photoPaths.isNotEmpty
                                    ? Image.network(
                                        v.photoPaths.first,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const ColoredBox(
                                          color: Color(0xFFE5E7EB),
                                          child: Icon(Icons.directions_car),
                                        ),
                                      )
                                    : const ColoredBox(
                                        color: Color(0xFFE5E7EB),
                                        child: Icon(Icons.directions_car),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${v.make} ${v.model}',
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${v.category} · ${v.pickupArea}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${(v.dailyRateNgn / 1000).round()} / day (₦${v.dailyRateNgn})',
                                    style: const TextStyle(
                                      color: Color(0xFF13382C),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isFav ? Colors.red : Colors.grey,
                              ),
                              onPressed: () => _toggleFavorite(v.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBookingsTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        title: const Text('My Bookings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F5ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_today_rounded,
                    size: 48, color: Color(0xFF13382C)),
              ),
              const SizedBox(height: 20),
              const Text(
                'No Active Bookings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your upcoming trips and vehicle reservation requests will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => setState(() => _currentTab = 0),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF13382C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Browse Popular Cars'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      appBar: AppBar(
        title: const Text('Account & Preferences',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF13382C),
                  child: const Text(
                    'AO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adanna Okafor',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Customer · Abuja, Nigeria',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9F5ED),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Verified Customer',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13382C),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Switch Role Workspaces',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildSettingsTile(
            icon: Icons.car_rental_rounded,
            title: 'Owner Workspace',
            subtitle: 'Preview listing and vehicle management workflows',
            onTap: widget.onSwitchToOwner,
          ),
          _buildSettingsTile(
            icon: Icons.badge_outlined,
            title: 'Driver Workspace',
            subtitle: 'Preview assigned trips and verification screen',
            onTap: widget.onSwitchToDriver,
          ),
          const SizedBox(height: 24),
          const Text('Preferences',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildSettingsTile(
            icon: Icons.receipt_long_rounded,
            title: 'Payments & Invoices',
            subtitle: 'Verified receipts, deposits and refund status',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const CustomerPaymentsScreen(customerId: 'demo_customer'),
              ),
            ),
          ),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Trip alerts and discounts',
            onTap: _showNotificationSheet,
          ),
          _buildSettingsTile(
            icon: Icons.security_rounded,
            title: 'Privacy & Security',
            subtitle: 'Permissions and account security',
          ),
          _buildSettingsTile(
            icon: Icons.support_agent_rounded,
            title: 'Customer Support',
            subtitle: 'Abuja dedicated concierge line',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF13382C), size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
        subtitle: Text(subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFEEEEEE))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.explore_outlined, 'Explore'),
              _buildNavItem(2, Icons.calendar_today_rounded, 'Bookings'),
              _buildNavItem(3, Icons.person_outline_rounded, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final active = _currentTab == index;
    return InkWell(
      onTap: () => setState(() => _currentTab = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF13382C) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: active ? Colors.white : const Color(0xFF6B7280),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LuxuryVehicleDetailScreen extends StatefulWidget {
  const LuxuryVehicleDetailScreen({
    super.key,
    required this.vehicle,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final VehicleListing vehicle;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  State<LuxuryVehicleDetailScreen> createState() =>
      _LuxuryVehicleDetailScreenState();
}

class _LuxuryVehicleDetailScreenState extends State<LuxuryVehicleDetailScreen> {
  late bool _isFavorite;
  String _selectedMode = 'selfDrive';

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
    _selectedMode = widget.vehicle.rentalMode == 'chauffeur'
        ? 'chauffeur'
        : 'selfDrive';
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vehicle;
    final rateInDollars = (v.dailyRateNgn / 1000).round();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8F9),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF13382C),
            leading: CircleAvatar(
              backgroundColor: Colors.white.withOpacity(0.85),
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: Color(0xFF13382C)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.85),
                child: IconButton(
                  icon: Icon(
                    _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _isFavorite ? Colors.red : const Color(0xFF13382C),
                  ),
                  onPressed: () {
                    setState(() => _isFavorite = !_isFavorite);
                    widget.onToggleFavorite();
                  },
                ),
              ),
              const SizedBox(width: 14),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  v.photoPaths.isNotEmpty
                      ? Image.network(
                          v.photoPaths.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF13382C),
                            child: Icon(Icons.directions_car,
                                size: 80, color: Colors.white54),
                          ),
                        )
                      : const ColoredBox(
                          color: Color(0xFF13382C),
                          child: Icon(Icons.directions_car,
                              size: 80, color: Colors.white54),
                        ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${v.make} ${v.model}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${v.year} · ${v.category} · ${v.pickupArea}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF13382C),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$$rateInDollars / day',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '₦${v.dailyRateNgn}',
                              style: TextStyle(
                                color: const Color(0xFF6EE7B7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Specifications',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          icon: Icons.people_alt_outlined,
                          title: 'Passengers',
                          value: '${v.seats} Seats',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSpecCard(
                          icon: v.fuelType == 'Electric'
                              ? Icons.bolt_rounded
                              : Icons.local_gas_station_outlined,
                          title: 'Power',
                          value: v.fuelType,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildSpecCard(
                          icon: Icons.speed_rounded,
                          title: 'Transmission',
                          value: v.transmission,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildSpecCard(
                          icon: Icons.color_lens_outlined,
                          title: 'Colour',
                          value: v.colour,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Description',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    v.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Rental Mode',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (v.rentalMode == 'selfDrive' ||
                          v.rentalMode == 'both')
                        Expanded(
                          child: _buildRentalModeButton(
                            title: 'Self-Drive',
                            icon: Icons.directions_car_rounded,
                            selected: _selectedMode == 'selfDrive',
                            onTap: () =>
                                setState(() => _selectedMode = 'selfDrive'),
                          ),
                        ),
                      if (v.rentalMode == 'both') const SizedBox(width: 12),
                      if (v.rentalMode == 'chauffeur' ||
                          v.rentalMode == 'both')
                        Expanded(
                          child: _buildRentalModeButton(
                            title: 'Chauffeur Driven',
                            icon: Icons.badge_outlined,
                            selected: _selectedMode == 'chauffeur',
                            onTap: () =>
                                setState(() => _selectedMode = 'chauffeur'),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingRequestScreen(vehicle: v),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF13382C),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Reserve This Vehicle',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Minimum rental: ${v.minimumRentalDays} day(s) · Pickup in ${v.pickupArea}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F5ED),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF13382C)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRentalModeButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF13382C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? const Color(0xFF13382C)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : const Color(0xFF374151),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
