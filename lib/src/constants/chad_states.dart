class ChadStateOption {
  const ChadStateOption({
    required this.code,
    required this.nameAr,
    required this.nameFr,
  });

  final String code;
  final String nameAr;
  final String nameFr;
}

const List<ChadStateOption> kChadStates = <ChadStateOption>[
  ChadStateOption(code: 'barh_el_gazel', nameAr: 'بحر الغزال', nameFr: 'Barh El Gazel'),
  ChadStateOption(code: 'batha', nameAr: 'البطحاء', nameFr: 'Batha'),
  ChadStateOption(code: 'borkou', nameAr: 'بوركو', nameFr: 'Borkou'),
  ChadStateOption(code: 'chari_baguirmi', nameAr: 'شاري باقرمي', nameFr: 'Chari-Baguirmi'),
  ChadStateOption(code: 'ennedi_est', nameAr: 'إنيدي الشرقية', nameFr: 'Ennedi-Est'),
  ChadStateOption(code: 'ennedi_ouest', nameAr: 'إنيدي الغربية', nameFr: 'Ennedi-Ouest'),
  ChadStateOption(code: 'guera', nameAr: 'قيرا', nameFr: 'Guera'),
  ChadStateOption(code: 'hadjer_lamis', nameAr: 'هجر لميس', nameFr: 'Hadjer-Lamis'),
  ChadStateOption(code: 'kanem', nameAr: 'كانم', nameFr: 'Kanem'),
  ChadStateOption(code: 'lac', nameAr: 'لاك', nameFr: 'Lac'),
  ChadStateOption(
    code: 'logone_occidental',
    nameAr: 'لوقون الغربية',
    nameFr: 'Logone Occidental',
  ),
  ChadStateOption(
    code: 'logone_oriental',
    nameAr: 'لوقون الشرقية',
    nameFr: 'Logone Oriental',
  ),
  ChadStateOption(code: 'mandoul', nameAr: 'مندول', nameFr: 'Mandoul'),
  ChadStateOption(
    code: 'mayo_kebbi_est',
    nameAr: 'مايو كيبي الشرقية',
    nameFr: 'Mayo-Kebbi Est',
  ),
  ChadStateOption(
    code: 'mayo_kebbi_ouest',
    nameAr: 'مايو كيبي الغربية',
    nameFr: 'Mayo-Kebbi Ouest',
  ),
  ChadStateOption(code: 'moyen_chari', nameAr: 'مويان شاري', nameFr: 'Moyen-Chari'),
  ChadStateOption(code: 'n_djamena', nameAr: 'أنجمينا', nameFr: "N'Djamena"),
  ChadStateOption(code: 'ouaddai', nameAr: 'واداي', nameFr: 'Ouaddai'),
  ChadStateOption(code: 'salamat', nameAr: 'سلامات', nameFr: 'Salamat'),
  ChadStateOption(code: 'sila', nameAr: 'سيلا', nameFr: 'Sila'),
  ChadStateOption(code: 'tandjile', nameAr: 'تنجيلي', nameFr: 'Tandjile'),
  ChadStateOption(code: 'tibesti', nameAr: 'تيبستي', nameFr: 'Tibesti'),
  ChadStateOption(code: 'wadi_fira', nameAr: 'وادي فيرا', nameFr: 'Wadi Fira'),
];
