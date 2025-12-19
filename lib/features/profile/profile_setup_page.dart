import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// === Opzioni fisse ===
const _roles = <String>[
  'produttore','grossista','intermediario','fruttivendolo','agrotecnico','altro',
];
const _hectaresRanges = <String>['1-5','6-10','11-20','21-50','>50'];

// Province (sigla + nome)
const _provincesPairs = <Map<String, String>>[
  {'code':'AG','name':'Agrigento'},{'code':'AL','name':'Alessandria'},{'code':'AN','name':'Ancona'},
  {'code':'AO','name':'Aosta'},{'code':'AP','name':'Ascoli Piceno'},{'code':'AQ','name':'L\'Aquila'},
  {'code':'AR','name':'Arezzo'},{'code':'AT','name':'Asti'},{'code':'AV','name':'Avellino'},
  {'code':'BA','name':'Bari'},{'code':'BG','name':'Bergamo'},{'code':'BI','name':'Biella'},
  {'code':'BL','name':'Belluno'},{'code':'BN','name':'Benevento'},{'code':'BO','name':'Bologna'},
  {'code':'BR','name':'Brindisi'},{'code':'BS','name':'Brescia'},{'code':'BT','name':'Barletta-Andria-Trani'},
  {'code':'BZ','name':'Bolzano'},{'code':'CA','name':'Cagliari'},{'code':'CB','name':'Campobasso'},
  {'code':'CE','name':'Caserta'},{'code':'CH','name':'Chieti'},{'code':'CL','name':'Caltanissetta'},
  {'code':'CN','name':'Cuneo'},{'code':'CO','name':'Como'},{'code':'CR','name':'Cremona'},
  {'code':'CS','name':'Cosenza'},{'code':'CT','name':'Catania'},{'code':'CZ','name':'Catanzaro'},
  {'code':'EN','name':'Enna'},{'code':'FC','name':'Forlì-Cesena'},{'code':'FE','name':'Ferrara'},
  {'code':'FG','name':'Foggia'},{'code':'FI','name':'Firenze'},{'code':'FM','name':'Fermo'},
  {'code':'FR','name':'Frosinone'},{'code':'GE','name':'Genova'},{'code':'GO','name':'Gorizia'},
  {'code':'GR','name':'Grosseto'},{'code':'IM','name':'Imperia'},{'code':'IS','name':'Isernia'},
  {'code':'KR','name':'Crotone'},{'code':'LC','name':'Lecco'},{'code':'LE','name':'Lecce'},
  {'code':'LI','name':'Livorno'},{'code':'LO','name':'Lodi'},{'code':'LT','name':'Latina'},
  {'code':'LU','name':'Lucca'},{'code':'MB','name':'Monza e della Brianza'},{'code':'MC','name':'Macerata'},
  {'code':'ME','name':'Messina'},{'code':'MI','name':'Milano'},{'code':'MN','name':'Mantova'},
  {'code':'MO','name':'Modena'},{'code':'MS','name':'Massa-Carrara'},{'code':'MT','name':'Matera'},
  {'code':'NA','name':'Napoli'},{'code':'NO','name':'Novara'},{'code':'NU','name':'Nuoro'},
  {'code':'OR','name':'Oristano'},{'code':'PA','name':'Palermo'},{'code':'PC','name':'Piacenza'},
  {'code':'PD','name':'Padova'},{'code':'PE','name':'Pescara'},{'code':'PG','name':'Perugia'},
  {'code':'PI','name':'Pisa'},{'code':'PN','name':'Pordenone'},{'code':'PO','name':'Prato'},
  {'code':'PR','name':'Parma'},{'code':'PT','name':'Pistoia'},{'code':'PU','name':'Pesaro e Urbino'},
  {'code':'PV','name':'Pavia'},{'code':'PZ','name':'Potenza'},{'code':'RA','name':'Ravenna'},
  {'code':'RC','name':'Reggio Calabria'},{'code':'RE','name':'Reggio Emilia'},{'code':'RG','name':'Ragusa'},
  {'code':'RI','name':'Rieti'},{'code':'RM','name':'Roma'},{'code':'RN','name':'Rimini'},
  {'code':'RO','name':'Rovigo'},{'code':'SA','name':'Salerno'},{'code':'SI','name':'Siena'},
  {'code':'SO','name':'Sondrio'},{'code':'SP','name':'La Spezia'},{'code':'SR','name':'Siracusa'},
  {'code':'SS','name':'Sassari'},{'code':'SU','name':'Sud Sardegna'},{'code':'TA','name':'Taranto'},
  {'code':'TE','name':'Teramo'},{'code':'TN','name':'Trento'},{'code':'TO','name':'Torino'},
  {'code':'TP','name':'Trapani'},{'code':'TR','name':'Terni'},{'code':'TS','name':'Trieste'},
  {'code':'TV','name':'Treviso'},{'code':'UD','name':'Udine'},{'code':'VA','name':'Varese'},
  {'code':'VB','name':'Verbano-Cusio-Ossola'},{'code':'VC','name':'Vercelli'},{'code':'VE','name':'Venezia'},
  {'code':'VI','name':'Vicenza'},{'code':'VR','name':'Verona'},{'code':'VT','name':'Viterbo'},
  {'code':'VV','name':'Vibo Valentia'},
];

// Prodotti
const _allProducts = <String>[
  'Agli','Aglione','Albicocche','Albicocche secche','Anacardi','Ananas','Angurie','Arance','Asparagi','Avocado',
  'Banane','Basilico','Bietole','Broccoli','Cachi','Carciofi','Carote','Castagne','Cavolfiore','Cavoli','Cetrioli',
  'Cicoria','Ciliegie','Cime di Rapa','Cipolle','Clementine','Cocco','Datteri','Fagioli','Fagiolini','Fave','Fichi',
  'Fichi d\'india','Fichi secchi','Finocchi','Fragole','Fragole di bosco','Fruttivendoli','Frutto della passione',
  'Funghi','Gelso','Kiwi','Lamponi','Lattughe','Lime','Limoni','Mandarini','Mandorle','Manghi','Melanzane','Mele',
  'Melograno','Meloni','Mirtilli','Misto di bosco','More','Nespole','Nocciole','Noci','Olive','Papaia','Patate',
  'Peperoni','Pere','Pesche','Pinoli','Piselli','Pistacchi','Pomodoro','Pompelmi','Porri','Prezzemolo','Prugne',
  'Radicchio','Rape','Ravanelli','Ribes','Rosmarino','Rucola','Salvia','Sedani','Semi di zucca','Spinaci','Susine',
  'Tartufo','Uva da tavola','Uva da vino','Uva secca','Zenzero','Zucche','Zucchine',
];

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});
  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _firstName = TextEditingController();
  final _lastName  = TextEditingController();
  final _email     = TextEditingController();
  final _phone     = TextEditingController();

  String? _role;
  String? _provinceCode;
  String? _provinceName;
  final Set<String> _selectedProducts = {};
  String? _hectaresRange;
  bool? _km0;

  bool _loading = true;
  bool _saving  = false;
  String? _error;
  bool _dirty = false;
  bool _alreadyComplete = false;

  bool get _isProducer => _role == 'produttore';

  @override
  void initState() {
    super.initState();
    // segna dirty se l'utente modifica campi
    for (final c in [_firstName, _lastName, _phone]) {
      c.addListener(() => setState(() => _dirty = true));
    }
    _loadInitial();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() { _loading = false; _error = 'Non autenticato'; });
        return;
      }
      _email.text = user.email ?? '';

      final db = FirebaseFirestore.instance;
      final snap = await db.collection('users_private').doc(user.uid).get();
      final data = snap.data() as Map<String, dynamic>?;

      if (data != null) {
        _firstName.text = (data['firstName'] ?? '') as String;
        _lastName.text  = (data['lastName'] ?? '') as String;
        _phone.text     = (data['phone'] ?? '') as String;
        _role           = (data['role'] as String?) ?? _role;
        _provinceCode   = (data['provinceCode'] as String?) ?? (data['province'] as String?);
        _provinceName   = (data['provinceName'] as String?) ??
            _provincesPairs.firstWhere(
                  (p) => p['code'] == _provinceCode,
              orElse: () => {'name': ''},
            )['name'];
        final List prods = (data['products'] as List?) ?? const [];
        _selectedProducts
          ..clear()
          ..addAll(prods.map((e) => e.toString()));

        _hectaresRange = (data['hectaresRange'] as String?) ?? _hectaresRange;
        _km0           = (data['km0'] as bool?) ?? _km0;
        _alreadyComplete = _isComplete(data);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; _dirty = false; });
    }
  }

  bool _nonEmptyStr(dynamic v) => v is String && v.trim().isNotEmpty;

  bool _isComplete(Map<String, dynamic> d) {
    final hasProvince = _nonEmptyStr(d['province']) || _nonEmptyStr(d['provinceCode']) || _nonEmptyStr(d['provinceName']);
    final baseOk = _nonEmptyStr(d['firstName']) &&
        _nonEmptyStr(d['lastName'])  &&
        _nonEmptyStr(d['phone'])     &&
        _nonEmptyStr(d['role'])      &&
        hasProvince                  &&
        (d['products'] is List && (d['products'] as List).isNotEmpty);
    if (!baseOk) return false;
    if (d['role'] == 'produttore') {
      return _nonEmptyStr(d['hectaresRange']) && (d['km0'] is bool);
    }
    return true;
  }

  Future<void> _pickProducts() async {
    final tmp = Set<String>.from(_selectedProducts);
    await showModalBottomSheet(
      context: context, isScrollControlled: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false, initialChildSize: 0.9, minChildSize: 0.6, maxChildSize: 0.95,
          builder: (_, controller) => StatefulBuilder(
            builder: (context, setLocal) {
              void toggle(String p, bool v) {
                v ? tmp.add(p) : tmp.remove(p);
                setLocal(() {});
              }
              return Column(
                children: [
                  const SizedBox(height: 8),
                  Container(height: 4, width: 40, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Seleziona prodotti')),
                        TextButton.icon(onPressed: () { tmp..clear()..addAll(_allProducts); setLocal(() {}); },
                            icon: const Icon(Icons.done_all), label: const Text('Tutti')),
                        const SizedBox(width: 8),
                        TextButton.icon(onPressed: () { tmp.clear(); setLocal(() {}); },
                            icon: const Icon(Icons.clear_all), label: const Text('Nessuno')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller, itemCount: _allProducts.length,
                      itemBuilder: (_, i) {
                        final p = _allProducts[i];
                        final checked = tmp.contains(p);
                        return CheckboxListTile(
                          title: Text(p), value: checked,
                          onChanged: (v) => toggle(p, v ?? false),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: OutlinedButton(
                            onPressed: () => Navigator.pop(context), child: const Text('Annulla'))),
                        const SizedBox(width: 12),
                        Expanded(child: FilledButton(
                          onPressed: () {
                            _selectedProducts..clear()..addAll(tmp);
                            _dirty = true;
                            Navigator.pop(context);
                            setState(() {});
                          },
                          child: const Text('Conferma'),
                        )),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedProducts.isEmpty) {
      setState(() => _error = 'Seleziona almeno un prodotto.');
      return;
    }
    if (_provinceCode == null || (_provinceName == null || _provinceName!.trim().isEmpty)) {
      setState(() => _error = 'Seleziona la provincia.');
      return;
    }
    if (_isProducer) {
      if (_hectaresRange == null) { setState(() => _error = 'Indica gli ettari coltivati.'); return; }
      if (_km0 == null) { setState(() => _error = 'Indica se fai Km0.'); return; }
    }

    setState(() { _saving = true; _error = null; });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final db = FirebaseFirestore.instance;

      // PRIVATO
      await db.collection('users_private').doc(user.uid).set({
        'uid'   : user.uid,
        'email' : user.email,
        'firstName': _firstName.text.trim(),
        'lastName' : _lastName.text.trim(),
        'phone'    : _phone.text.trim(),
        'role'     : _role,
        'provinceCode': _provinceCode,
        'provinceName': _provinceName,
        'province'    : _provinceCode, // compatibilità
        'products'     : _selectedProducts.toList(),
        'hectaresRange': _isProducer ? _hectaresRange : null,
        'km0'          : _isProducer ? _km0 : null,
        'provider': user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password',
        'profileComplete': true,
        'updatedAt'      : FieldValue.serverTimestamp(),
        'createdAt'      : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // PUBBLICO
      final displayName = '${_firstName.text.trim()} ${_lastName.text.trim()}'.trim();
      await db.collection('public_profiles').doc(user.uid).set({
        'displayName' : displayName,
        'role'        : _role,
        'provinceCode': _provinceCode,
        'provinceName': _provinceName,
        'products'    : _selectedProducts.toList(),
        'updatedAt'   : FieldValue.serverTimestamp(),
        'createdAt'   : FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        _dirty = false;
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final already = _alreadyComplete;
    final saveEnabled = !_saving && (!_alreadyComplete || _dirty);

    final chips = _selectedProducts.take(6).map((p) => Chip(label: Text(p))).toList();
    final more = (_selectedProducts.length > 6) ? Chip(label: Text('+${_selectedProducts.length - 6}')) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Completa profilo')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),

              if (already)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: MaterialBanner(
                    content: const Text('Il tuo profilo è già completo. Puoi chiudere o aggiornare i dati.'),
                    leading: const Icon(Icons.verified),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
                    ],
                  ),
                ),

              Text('Dati personali', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              TextFormField(
                controller: _firstName,
                decoration: const InputDecoration(labelText: 'Nome *', prefixIcon: Icon(Icons.person)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _lastName,
                decoration: const InputDecoration(labelText: 'Cognome *', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email, enabled: false,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone, keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefono *', prefixIcon: Icon(Icons.phone)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Obbligatorio' : null,
              ),

              const SizedBox(height: 16),
              Text('Profilazione', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _role,
                items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                decoration: const InputDecoration(labelText: 'Ruolo *', prefixIcon: Icon(Icons.work)),
                onChanged: (v) { setState(() { _role = v; _dirty = true; }); },
                validator: (v) => (v == null || v.isEmpty) ? 'Seleziona un ruolo' : null,
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _provinceCode,
                items: _provincesPairs
                    .map((p) => DropdownMenuItem(
                  value: p['code'],
                  child: Text('${p['name']} (${p['code']})'),
                ))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Provincia *', prefixIcon: Icon(Icons.location_on)),
                onChanged: (code) {
                  final match = _provincesPairs.firstWhere((p) => p['code'] == code);
                  setState(() {
                    _provinceCode = match['code'];
                    _provinceName = match['name'];
                    _dirty = true;
                  });
                },
                validator: (v) => (v == null || v.isEmpty) ? 'Seleziona la provincia' : null,
              ),

              const SizedBox(height: 12),
              Text('Prodotti trattati *'),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: -6, children: [
                ...chips,
                if (more != null) more,
                ActionChip(
                  label: const Text('Seleziona'),
                  avatar: const Icon(Icons.list),
                  onPressed: _pickProducts,
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                _selectedProducts.isEmpty
                    ? 'Nessun prodotto selezionato'
                    : '${_selectedProducts.length} prodotti selezionati',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),

              if (_isProducer) ...[
                const SizedBox(height: 16),
                Text('Dettagli produttore', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _hectaresRange,
                  items: _hectaresRanges.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                  decoration: const InputDecoration(labelText: 'Ettari coltivati *', prefixIcon: Icon(Icons.terrain)),
                  onChanged: (v) { setState(() { _hectaresRange = v; _dirty = true; }); },
                  validator: (v) => (v == null || v.isEmpty) ? 'Seleziona il range' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<bool>(
                  value: _km0,
                  items: const [
                    DropdownMenuItem(value: true, child: Text('Sì')),
                    DropdownMenuItem(value: false, child: Text('No')),
                  ],
                  decoration: const InputDecoration(labelText: 'Km0 *', prefixIcon: Icon(Icons.local_florist)),
                  onChanged: (v) { setState(() { _km0 = v; _dirty = true; }); },
                  validator: (v) => (v == null) ? 'Seleziona Sì o No' : null,
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: saveEnabled ? _save : null,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Salvataggio…' : (_alreadyComplete ? 'Aggiorna dati' : 'Salva e continua')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chiudi'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('I campi * sono obbligatori.'),
            ],
          ),
        ),
      ),
    );
  }
}
