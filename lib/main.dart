import 'package:flutter/material.dart';

void main() {
  runApp(const BrtApp());
}

const _green = Color(0xFF0B6B3A);
const _teal = Color(0xFF00A896);
const _ink = Color(0xFF173322);
const _surface = Color(0xFFF3FAF6);

class BrtApp extends StatelessWidget {
  const BrtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BRT Peshawar Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _teal,
          primary: _green,
          secondary: _teal,
          surface: _surface,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: _surface,
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: _green.withValues(alpha: 0.08)),
          ),
        ),
      ),
      home: const PortalHome(),
    );
  }
}

class PortalHome extends StatefulWidget {
  const PortalHome({super.key});

  @override
  State<PortalHome> createState() => _PortalHomeState();
}

class _PortalHomeState extends State<PortalHome> {
  PortalRole? _selectedRole;

  @override
  Widget build(BuildContext context) {
    final page = switch (_selectedRole) {
      PortalRole.passenger => PassengerDashboard(
          onLogout: () => setState(() => _selectedRole = null),
        ),
      PortalRole.driver => DriverDashboard(
          onLogout: () => setState(() => _selectedRole = null),
        ),
      PortalRole.admin => AdminDashboard(
          onLogout: () => setState(() => _selectedRole = null),
        ),
      null => RoleSelection(
          onSelect: (role) => setState(() => _selectedRole = role),
        ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: page,
    );
  }
}

enum PortalRole { passenger, driver, admin }

class RoleSelection extends StatelessWidget {
  const RoleSelection({super.key, required this.onSelect});

  final ValueChanged<PortalRole> onSelect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientShell(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 760;
                  final brand = const _BrandPanel();
                  final roles = Padding(
                    padding: const EdgeInsets.all(28),
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 18,
                      children: [
                        RoleCard(
                          icon: Icons.person,
                          title: 'Passenger',
                          description:
                              'Plan trips, book demo tickets, recharge your card, and track notifications.',
                          onTap: () => onSelect(PortalRole.passenger),
                        ),
                        RoleCard(
                          icon: Icons.badge,
                          title: 'Driver',
                          description:
                              'Review assigned buses, schedules, route stops, and service status.',
                          onTap: () => onSelect(PortalRole.driver),
                        ),
                        RoleCard(
                          icon: Icons.admin_panel_settings,
                          title: 'Admin',
                          description:
                              'Monitor buses, route occupancy, active schedules, complaints, and alerts.',
                          onTap: () => onSelect(PortalRole.admin),
                        ),
                      ],
                    ),
                  );

                  if (isNarrow) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [brand, roles],
                    );
                  }

                  return IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: brand),
                        Expanded(flex: 7, child: roles),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GradientShell extends StatelessWidget {
  const GradientShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      minHeight: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B3618), Color(0xFF16213E)],
        ),
      ),
      child: child,
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(36),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_green, _teal],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          LogoBadge(),
          SizedBox(height: 24),
          Text(
            'BRT Peshawar Management System',
            style: TextStyle(
              color: Colors.white,
              fontSize: 38,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 18),
          Text(
            'A Flutter web portal for passengers, drivers, and administrators, ready for static deployment on Vercel.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(24),
      ),
      alignment: Alignment.center,
      child: const Text(
        'ZU',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class RoleCard extends StatefulWidget {
  const RoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: _hovered ? 1.02 : 1,
        child: SizedBox(
          width: 260,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: widget.onTap,
            child: Ink(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FBF9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: _hovered ? _teal : const Color(0xFFDCE9E3),
                ),
                boxShadow: _hovered
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon, color: _teal, size: 38),
                  const SizedBox(height: 16),
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _green,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F7068),
                          height: 1.45,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> {
  double _balance = 560;
  String _start = demoStations.first;
  String _end = demoStations[4];
  String _complaint = '';
  final List<String> _notifications = [
    'Welcome back, Ayesha. Your Green Line card is active.',
    'Route GR-01 is operating every 7 minutes today.',
  ];
  final List<Ticket> _tickets = [
    Ticket('GR-01', 'Chamkani', 'Saddar', 80),
    Ticket('XR-03', 'University Town', 'Karkhano', 60),
  ];
  final List<Complaint> _complaints = [
    Complaint('Escalator maintenance requested at Saddar station.', 'open'),
  ];

  TripQuote get _quote {
    final startIndex = demoStations.indexOf(_start);
    final endIndex = demoStations.indexOf(_end);
    final stops =
        (startIndex - endIndex).abs().clamp(1, demoStations.length).toInt();
    return TripQuote(
      routeCode: stops > 4 ? 'XR-03' : 'GR-01',
      stops: stops,
      fare: stops * 20,
      minutes: stops * 4,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Passenger Dashboard',
      subtitle: 'Welcome, Ayesha Khan',
      icon: Icons.person,
      onLogout: widget.onLogout,
      children: [
        StatCard(
          label: 'Card balance',
          value: 'PKR ${_balance.toStringAsFixed(0)}',
          icon: Icons.account_balance_wallet,
          color: _green,
        ),
        StatCard(
          label: 'Recent tickets',
          value: '${_tickets.length}',
          icon: Icons.confirmation_number,
          color: _teal,
        ),
        StatCard(
          label: 'Unread alerts',
          value: '${_notifications.length}',
          icon: Icons.notifications_active,
          color: Colors.orange,
        ),
        FeaturePanel(
          title: 'Plan Trip',
          icon: Icons.route,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ResponsiveRow(
                children: [
                  DropdownCard(
                    label: 'Start station',
                    value: _start,
                    items: demoStations,
                    onChanged: (value) => setState(() => _start = value),
                  ),
                  DropdownCard(
                    label: 'Destination',
                    value: _end,
                    items: demoStations,
                    onChanged: (value) => setState(() => _end = value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  Chip(label: Text('Route ${_quote.routeCode}')),
                  Chip(label: Text('${_quote.stops} stops')),
                  Chip(label: Text('${_quote.minutes} min')),
                  Chip(label: Text('PKR ${_quote.fare.toStringAsFixed(0)}')),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _balance >= _quote.fare
                    ? () {
                        setState(() {
                          _balance -= _quote.fare;
                          _tickets.insert(
                            0,
                            Ticket(_quote.routeCode, _start, _end, _quote.fare),
                          );
                          _notifications.insert(
                            0,
                            'Ticket booked from $_start to $_end.',
                          );
                        });
                      }
                    : null,
                icon: const Icon(Icons.confirmation_number),
                label: const Text('Book demo ticket'),
              ),
            ],
          ),
        ),
        FeaturePanel(
          title: 'Bus Occupancy',
          icon: Icons.groups,
          child: Column(
            children: demoBuses
                .map(
                  (bus) => OccupancyTile(
                    title: '${bus.number} - ${bus.routeCode}',
                    subtitle: bus.routeName,
                    occupancy: bus.occupancy,
                  ),
                )
                .toList(),
          ),
        ),
        FeaturePanel(
          title: 'Recharge Card',
          icon: Icons.add_card,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [250, 500, 1000]
                .map(
                  (amount) => OutlinedButton(
                    onPressed: () => setState(() => _balance += amount),
                    child: Text('Add PKR $amount'),
                  ),
                )
                .toList(),
          ),
        ),
        FeaturePanel(
          title: 'Support Complaint',
          icon: Icons.support_agent,
          child: Column(
            children: [
              TextField(
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Describe your issue',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _complaint = value,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () {
                    if (_complaint.trim().length < 8) return;
                    setState(() {
                      _complaints.insert(0, Complaint(_complaint.trim(), 'open'));
                      _complaint = '';
                    });
                  },
                  child: const Text('Submit complaint'),
                ),
              ),
            ],
          ),
        ),
        ListPanel(
          title: 'Recent Tickets',
          icon: Icons.receipt_long,
          items: _tickets
              .map(
                (ticket) =>
                    '${ticket.routeCode}: ${ticket.start} to ${ticket.end} - PKR ${ticket.fare.toStringAsFixed(0)}',
              )
              .toList(),
        ),
        ListPanel(
          title: 'Notifications',
          icon: Icons.notifications,
          items: _notifications,
        ),
        ListPanel(
          title: 'My Complaints',
          icon: Icons.feedback,
          items: _complaints
              .map((complaint) => '${complaint.status.toUpperCase()}: ${complaint.text}')
              .toList(),
        ),
      ],
    );
  }
}

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  String _status = 'scheduled';

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Driver Dashboard',
      subtitle: 'Welcome, Bilal Ahmed',
      icon: Icons.badge,
      onLogout: widget.onLogout,
      children: [
        const StatCard(
          label: 'Assignments',
          value: '3',
          icon: Icons.event_available,
          color: _green,
        ),
        const StatCard(
          label: 'Active route',
          value: 'GR-01',
          icon: Icons.route,
          color: _teal,
        ),
        StatCard(
          label: 'Current status',
          value: _status.toUpperCase(),
          icon: Icons.directions_bus,
          color: Colors.orange,
        ),
        FeaturePanel(
          title: 'Assigned Schedules',
          icon: Icons.schedule,
          child: Column(
            children: demoSchedules
                .map(
                  (schedule) => ScheduleTile(
                    routeCode: schedule.routeCode,
                    bus: schedule.bus,
                    time: schedule.time,
                    status: schedule.status,
                  ),
                )
                .toList(),
          ),
        ),
        FeaturePanel(
          title: 'Update Service Status',
          icon: Icons.sync,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: ['scheduled', 'active', 'delayed', 'cancelled']
                .map(
                  (status) => ChoiceChip(
                    label: Text(status),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                  ),
                )
                .toList(),
          ),
        ),
        ListPanel(
          title: 'Route Stops',
          icon: Icons.location_on,
          items: demoStations,
        ),
      ],
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final List<Bus> _buses = List.of(demoBuses);
  final List<String> _alerts = ['Platform 2 cleaning starts after 10 PM.'];

  @override
  Widget build(BuildContext context) {
    return DashboardShell(
      title: 'Admin Dashboard',
      subtitle: 'Welcome, Operations Admin',
      icon: Icons.admin_panel_settings,
      onLogout: widget.onLogout,
      children: [
        const StatCard(
          label: 'Passengers',
          value: '1,284',
          icon: Icons.people,
          color: _green,
        ),
        const StatCard(
          label: 'Routes',
          value: '12',
          icon: Icons.alt_route,
          color: _teal,
        ),
        StatCard(
          label: 'Active buses',
          value: '${_buses.length}',
          icon: Icons.directions_bus_filled,
          color: Colors.orange,
        ),
        const StatCard(
          label: 'Open complaints',
          value: '4',
          icon: Icons.comment,
          color: Colors.redAccent,
        ),
        FeaturePanel(
          title: 'Bus Management',
          icon: Icons.directions_bus,
          child: Column(
            children: _buses
                .map(
                  (bus) => ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _teal.withValues(alpha: 0.12),
                      child: const Icon(Icons.directions_bus, color: _green),
                    ),
                    title: Text('${bus.number} - ${bus.routeCode}'),
                    subtitle: Text('${bus.routeName} - ${bus.occupancy}% occupied'),
                    trailing: IconButton(
                      tooltip: 'Remove bus',
                      onPressed: () => setState(() => _buses.remove(bus)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        FeaturePanel(
          title: 'Service Notification',
          icon: Icons.campaign,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FilledButton.icon(
                onPressed: () => setState(
                  () => _alerts.insert(
                    0,
                    'Service update sent to all passengers.',
                  ),
                ),
                icon: const Icon(Icons.send),
                label: const Text('Send demo notification'),
              ),
              const SizedBox(height: 12),
              ..._alerts.map((alert) => ListTile(title: Text(alert))),
            ],
          ),
        ),
        FeaturePanel(
          title: 'Bus Occupancy Module',
          icon: Icons.groups,
          child: Column(
            children: _buses
                .map(
                  (bus) => OccupancyTile(
                    title: '${bus.number} - ${bus.routeCode}',
                    subtitle: bus.routeName,
                    occupancy: bus.occupancy,
                  ),
                )
                .toList(),
          ),
        ),
        FeaturePanel(
          title: 'Active Schedules',
          icon: Icons.event_note,
          child: Column(
            children: demoSchedules
                .map(
                  (schedule) => ScheduleTile(
                    routeCode: schedule.routeCode,
                    bus: schedule.bus,
                    time: schedule.time,
                    status: schedule.status,
                  ),
                )
                .toList(),
          ),
        ),
        const ListPanel(
          title: 'Open Complaints',
          icon: Icons.comment,
          items: [
            'Passenger crowding near Hashtnagri station.',
            'Ticket kiosk needs maintenance at Saddar.',
            'Route XR-03 departure delayed during evening rush.',
          ],
        ),
      ],
    );
  }
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onLogout,
    required this.children,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onLogout;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            expandedHeight: 188,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            actions: [
              TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: Colors.white),
                label: const Text('Switch role', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(title),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_green, _teal]),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                    child: Row(
                      children: [
                        LogoBadge(key: ValueKey(icon)),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(22),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1180),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 18,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 270,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: _ink,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeaturePanel extends StatelessWidget {
  const FeaturePanel({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 560,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: _green),
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _green,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class ListPanel extends StatelessWidget {
  const ListPanel({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return FeaturePanel(
      title: title,
      icon: icon,
      child: items.isEmpty
          ? const Text('Nothing to show yet.')
          : Column(
              children: items
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.check_circle_outline, color: _teal),
                      title: Text(item),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class ResponsiveRow extends StatelessWidget {
  const ResponsiveRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: child,
                  ),
                )
                .toList(),
          );
        }
        return Row(
          children: children
              .map(
                (child) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: child,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class DropdownCard extends StatelessWidget {
  const DropdownCard({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: items
          .map(
            (item) => DropdownMenuItem(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    );
  }
}

class OccupancyTile extends StatelessWidget {
  const OccupancyTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.occupancy,
  });

  final String title;
  final String subtitle;
  final int occupancy;

  @override
  Widget build(BuildContext context) {
    final color = occupancy > 80 ? Colors.redAccent : occupancy > 60 ? Colors.orange : _teal;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: occupancy / 100,
            minHeight: 9,
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
      trailing: Text(
        '$occupancy%',
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class ScheduleTile extends StatelessWidget {
  const ScheduleTile({
    super.key,
    required this.routeCode,
    required this.bus,
    required this.time,
    required this.status,
  });

  final String routeCode;
  final String bus;
  final String time;
  final String status;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.directions_bus, color: _green),
      title: Text('$routeCode on $bus'),
      subtitle: Text(time),
      trailing: Chip(label: Text(status)),
    );
  }
}

class Ticket {
  const Ticket(this.routeCode, this.start, this.end, this.fare);

  final String routeCode;
  final String start;
  final String end;
  final double fare;
}

class Complaint {
  const Complaint(this.text, this.status);

  final String text;
  final String status;
}

class TripQuote {
  const TripQuote({
    required this.routeCode,
    required this.stops,
    required this.fare,
    required this.minutes,
  });

  final String routeCode;
  final int stops;
  final int fare;
  final int minutes;
}

class Bus {
  const Bus(this.number, this.routeCode, this.routeName, this.occupancy);

  final String number;
  final String routeCode;
  final String routeName;
  final int occupancy;
}

class DriverSchedule {
  const DriverSchedule(this.routeCode, this.bus, this.time, this.status);

  final String routeCode;
  final String bus;
  final String time;
  final String status;
}

const demoStations = [
  'Chamkani',
  'Hashtnagri',
  'Saddar',
  'University Town',
  'Hayatabad',
  'Karkhano',
  'Mall Road',
  'Tehkal',
];

const demoBuses = [
  Bus('ZU-101', 'GR-01', 'Chamkani to Hayatabad', 72),
  Bus('ZU-214', 'XR-03', 'University Town to Karkhano', 58),
  Bus('ZU-333', 'BL-07', 'Saddar circular service', 86),
];

const demoSchedules = [
  DriverSchedule('GR-01', 'ZU-101', '07:30 AM - 08:25 AM', 'scheduled'),
  DriverSchedule('XR-03', 'ZU-214', '09:10 AM - 10:00 AM', 'active'),
  DriverSchedule('BL-07', 'ZU-333', '04:30 PM - 05:20 PM', 'delayed'),
];
