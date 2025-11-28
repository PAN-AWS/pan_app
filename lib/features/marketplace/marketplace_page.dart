import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../marketplace/public_profile_page.dart';
import '../../app/widgets/app_nav_bar.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  State<MarketplacePage> createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  static const _any = 'Qualsiasi';

  String _role = _any;
  String _province = _any; // es. "AV - Avellino"
  String _product = _any;

  final _roles = const [
    _any,
    'produttore',
    'grossista',
    'intermediario',
    'fruttivendolo',
    'agrotecnico',
    'altro',
  ];

  final _provinces = const [
    _any,
    'AG - Agrigento','AL - Alessandria','AN - Ancona','AO - Aosta','AR - Arezzo','AP - Ascoli Piceno',
    'AT - Asti','AV - Avellino','BA - Bari','BT - Barletta-Andria-Trani','BL - Belluno','BN - Benevento',
    'BG - Bergamo','BI - Biella','BO - Bologna','BZ - Bolzano','BS - Brescia','BR - Brindisi',
    'CA - Cagliari','CL - Caltanissetta','CB - Campobasso','CE - Caserta','CT - Catania','CZ - Catanzaro',
    'CH - Chieti','CO - Como','CS - Cosenza','CR - Cremona','KR - Crotone','CN - Cuneo','EN - Enna',
    'FM - Fermo','FE - Ferrara','FI - Firenze','FG - Foggia','FC - Forlì-Cesena','FR - Frosinone',
    'GE - Genova','GO - Gorizia','GR - Grosseto','IM - Imperia','IS - Isernia','SP - La Spezia',
    'AQ - L’Aquila','LT - Latina','LE - Lecce','LC - Lecco','LI - Livorno','LO - Lodi','LU - Lucca',
    'MC - Macerata','MN - Mantova','MS - Massa-Carrara','MT - Matera','ME - Messina','MI - Milano',
    'MO - Modena','MB - Monza e Brianza','NA - Napoli','NO - Novara','NU - Nuoro','OR - Oristano',
    'PD - Padova','PA - Palermo','PR - Parma','PV - Pavia','PG - Perugia','PU - Pesaro e Urbino',
    'PE - Pescara','PC - Piacenza','PI - Pisa','PT - Pistoia','PN - Pordenone','PZ - Potenza',
    'PO - Prato','RG - Ragusa','RA - Ravenna','RC - Reggio Calabria','RE - Reggio Emilia','RI - Rieti',
    'RN - Rimini','RM - Roma','RO - Rovigo','SA - Salerno','SS - Sassari','SV - Savona','SI - Siena',
    'SR - Siracusa','SO - Sondrio','SU - Sud Sardegna','TA - Taranto','TE - Teramo','TR - Terni',
    'TO - Torino','TP - Trapani','TN - Trento','TV - Treviso','TS - Trieste','UD - Udine','VA - Varese',
    'VE - Venezia','VB - Verbano-Cusio-Ossola','VC - Vercelli','VR - Verona','VV - Vibo Valentia',
    'VI - Vicenza','VT - Viterbo',
  ];

  final _products = const [
    _any,
    'Aglio','Aglione','Albicocche','Albicocche secche','Anacardi','Ananas','Angurie','Arance','Asparagi','Avocado',
    'Banane','Basilico','Bietole','Broccoli','Cachi','Carciofi','Carote','Castagne','Cavolfiore','Cavoli',
    'Cetrioli','Cicoria','Ciliegie','Cime di Rapa','Cipolle','Clementine','Cocco','Datteri','Fagioli',
    'Fagiolini','Fave','Fichi','Fichi d\'india','Fichi secchi','Finocchi','Fragole','Fragole di bosco',
    'Frutto della passione','Funghi','Gelso','Kiwi','Lamponi','Lattughe','Lime','Limoni','Mandarini','Mandorle',
    'Manghi','Melanzane','Mele','Melograno','Meloni','Mirtilli','Misto di bosco','More','Nespole','Nocciole',
    'Noci','Olive','Papaia','Patate','Peperoni','Pere','Pesche','Pinoli','Piselli','Pistacchi','Pomodoro',
    'Pompelmi','Porri','Prezzemolo','Prugne','Radicchio','Rape','Ravanelli','Ribes','Rosmarino','Rucola',
    'Salvia','Sedani','Semi di zucca','Spinaci','Susine','Tartufo','Uva da tavola','Uva da vino','Uva secca',
    'Zenzero','Zucche','Zucchine'
  ];

  // Stato risultati + paginazione
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _loading = false;
  bool _hasMore = true;

  bool get _needsLocalProvinceFilter =>
      _product == _any && _role != _any && _province != _any;

  Query<Map<String, dynamic>> _baseQuery({int limit = 20}) {
    Query<Map<String, dynamic>> q =
    FirebaseFirestore.instance.collection('public_profiles');

    if (_product != _any) {
      q = q.where('products', arrayContains: _product);
      return q.limit(limit);
    }

    if (_needsLocalProvinceFilter) {
      q = q.where('role', isEqualTo: _role);
      return q.limit(limit);
    }

    if (_role != _any) {
      q = q.where('role', isEqualTo: _role);
    } else if (_province != _any) {
      final sigla = _province.contains(' - ') ? _province.split(' - ').first : _province;
      q = q.where('provinceCode', isEqualTo: sigla);
    } else {
      q = q.orderBy('displayName');
    }

    return q.limit(limit);
  }

  Future<void> _refresh() async {
    setState(() { _items.clear(); _lastDoc = null; _hasMore = true; });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    setState(() => _loading = true);

    var q = _baseQuery(limit: 20);
    if (_lastDoc != null) {
      q = q.startAfterDocument(_lastDoc!);
    }
    final snap = await q.get();

    var docs = snap.docs;

    if (_needsLocalProvinceFilter) {
      final sigla = _province.contains(' - ') ? _province.split(' - ').first : _province;
      docs = docs.where((d) => (d.data()['provinceCode'] ?? '') == sigla).toList();
    }

    if (docs.isEmpty) {
      setState(() { _hasMore = false; _loading = false; });
      return;
    }

    setState(() {
      _items.addAll(docs);
      _lastDoc = docs.last;
      _loading = false;
      _hasMore = docs.length == 20;
    });
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _onFilterChanged(void Function() update) {
    update();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final isWide = w >= 700;
                if (isWide) {
                  // griglia 3 colonne su desktop/tablet
                  return Row(
                    children: [
                      Expanded(child: _buildDropdown('Ruolo', _role, _roles, (v) => _onFilterChanged(() => _role = v ?? _any))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDropdown('Provincia', _province, _provinces, (v) => _onFilterChanged(() => _province = v ?? _any))),
                      const SizedBox(width: 8),
                      Expanded(child: _buildDropdown('Prodotto', _product, _products, (v) => _onFilterChanged(() => _product = v ?? _any))),
                    ],
                  );
                } else {
                  // colonna su schermi stretti
                  return Column(
                    children: [
                      _buildDropdown('Ruolo', _role, _roles, (v) => _onFilterChanged(() => _role = v ?? _any)),
                      const SizedBox(height: 8),
                      _buildDropdown('Provincia', _province, _provinces, (v) => _onFilterChanged(() => _province = v ?? _any)),
                      const SizedBox(height: 8),
                      _buildDropdown('Prodotto', _product, _products, (v) => _onFilterChanged(() => _product = v ?? _any)),
                    ],
                  );
                }
              },
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                itemCount: _items.length + 1,
                separatorBuilder: (_, __) => const Divider(height: 0),
                itemBuilder: (_, i) {
                  if (i == _items.length) {
                    // footer “carica altri”
                    if (_loading) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (_hasMore) {
                      // trigger caricamento quando arriva in fondo
                      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMore());
                      return const SizedBox(height: 72);
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: Text('Fine risultati')),
                    );
                  }

                  final d = _items[i].data();
                  final uid = _items[i].id;
                  final name = (d['displayName'] ?? '').toString();
                  final role = (d['role'] ?? '-').toString();
                  final provCode = (d['provinceCode'] ?? '-').toString();
                  final provName = (d['provinceName'] ?? '').toString();
                  final prov = provName.isNotEmpty ? '$provName ($provCode)' : provCode;

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name.isEmpty ? '-' : name),
                    subtitle: Text('$role • $prov'), // niente email
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PublicProfilePage(uid: uid)),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppNavBar(currentIndex: 2),
    );
  }

  Widget _buildDropdown(
      String label,
      String value,
      List<String> items,
      ValueChanged<String?> onChanged,
      ) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : _any,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}
