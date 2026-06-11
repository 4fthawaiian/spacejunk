/// Country/organisation flag + name lookup for CelesTrak OWNER codes.
///
/// Sources:
///   https://celestrak.org/satcat/sources.php
///   https://en.wikipedia.org/wiki/ISO_3166-1
library;

/// Information about a country or organisation.
class CountryInfo {
  final String ownerCode;
  final String name;
  final String flag;
  final String? isoCode;

  const CountryInfo({
    required this.ownerCode,
    required this.name,
    required this.flag,
    this.isoCode,
  });
}

const Map<String, CountryInfo> _ownerMap = {
  'ALG': CountryInfo(ownerCode: 'ALG', name: 'Algeria', flag: '🇩🇿', isoCode: 'DZ'),
  'ANG': CountryInfo(ownerCode: 'ANG', name: 'Angola', flag: '🇦🇴', isoCode: 'AO'),
  'ARGN': CountryInfo(ownerCode: 'ARGN', name: 'Argentina', flag: '🇦🇷', isoCode: 'AR'),
  'ARM': CountryInfo(ownerCode: 'ARM', name: 'Armenia', flag: '🇦🇲', isoCode: 'AM'),
  'ASRA': CountryInfo(ownerCode: 'ASRA', name: 'Austria', flag: '🇦🇹', isoCode: 'AT'),
  'AUS': CountryInfo(ownerCode: 'AUS', name: 'Australia', flag: '🇦🇺', isoCode: 'AU'),
  'AZER': CountryInfo(ownerCode: 'AZER', name: 'Azerbaijan', flag: '🇦🇿', isoCode: 'AZ'),
  'BEL': CountryInfo(ownerCode: 'BEL', name: 'Belgium', flag: '🇧🇪', isoCode: 'BE'),
  'BELA': CountryInfo(ownerCode: 'BELA', name: 'Belarus', flag: '🇧🇾', isoCode: 'BY'),
  'BERM': CountryInfo(ownerCode: 'BERM', name: 'Bermuda', flag: '🇧🇲', isoCode: 'BM'),
  'BGD': CountryInfo(ownerCode: 'BGD', name: 'Bangladesh', flag: '🇧🇩', isoCode: 'BD'),
  'BHR': CountryInfo(ownerCode: 'BHR', name: 'Bahrain', flag: '🇧🇭', isoCode: 'BH'),
  'BHUT': CountryInfo(ownerCode: 'BHUT', name: 'Bhutan', flag: '🇧🇹', isoCode: 'BT'),
  'BOL': CountryInfo(ownerCode: 'BOL', name: 'Bolivia', flag: '🇧🇴', isoCode: 'BO'),
  'BRAZ': CountryInfo(ownerCode: 'BRAZ', name: 'Brazil', flag: '🇧🇷', isoCode: 'BR'),
  'BUL': CountryInfo(ownerCode: 'BUL', name: 'Bulgaria', flag: '🇧🇬', isoCode: 'BG'),
  'BWA': CountryInfo(ownerCode: 'BWA', name: 'Botswana', flag: '🇧🇼', isoCode: 'BW'),
  'CA': CountryInfo(ownerCode: 'CA', name: 'Canada', flag: '🇨🇦', isoCode: 'CA'),
  'CHLE': CountryInfo(ownerCode: 'CHLE', name: 'Chile', flag: '🇨🇱', isoCode: 'CL'),
  'COL': CountryInfo(ownerCode: 'COL', name: 'Colombia', flag: '🇨🇴', isoCode: 'CO'),
  'CRI': CountryInfo(ownerCode: 'CRI', name: 'Costa Rica', flag: '🇨🇷', isoCode: 'CR'),
  'CZCH': CountryInfo(ownerCode: 'CZCH', name: 'Czech Republic', flag: '🇨🇿', isoCode: 'CZ'),
  'DEN': CountryInfo(ownerCode: 'DEN', name: 'Denmark', flag: '🇩🇰', isoCode: 'DK'),
  'DJI': CountryInfo(ownerCode: 'DJI', name: 'Djibouti', flag: '🇩🇯', isoCode: 'DJ'),
  'ECU': CountryInfo(ownerCode: 'ECU', name: 'Ecuador', flag: '🇪🇨', isoCode: 'EC'),
  'EGYP': CountryInfo(ownerCode: 'EGYP', name: 'Egypt', flag: '🇪🇬', isoCode: 'EG'),
  'EST': CountryInfo(ownerCode: 'EST', name: 'Estonia', flag: '🇪🇪', isoCode: 'EE'),
  'ETH': CountryInfo(ownerCode: 'ETH', name: 'Ethiopia', flag: '🇪🇹', isoCode: 'ET'),
  'FIN': CountryInfo(ownerCode: 'FIN', name: 'Finland', flag: '🇫🇮', isoCode: 'FI'),
  'FR': CountryInfo(ownerCode: 'FR', name: 'France', flag: '🇫🇷', isoCode: 'FR'),
  'GER': CountryInfo(ownerCode: 'GER', name: 'Germany', flag: '🇩🇪', isoCode: 'DE'),
  'GHA': CountryInfo(ownerCode: 'GHA', name: 'Ghana', flag: '🇬🇭', isoCode: 'GH'),
  'GREC': CountryInfo(ownerCode: 'GREC', name: 'Greece', flag: '🇬🇷', isoCode: 'GR'),
  'GUAT': CountryInfo(ownerCode: 'GUAT', name: 'Guatemala', flag: '🇬🇹', isoCode: 'GT'),
  'HRV': CountryInfo(ownerCode: 'HRV', name: 'Croatia', flag: '🇭🇷', isoCode: 'HR'),
  'HUN': CountryInfo(ownerCode: 'HUN', name: 'Hungary', flag: '🇭🇺', isoCode: 'HU'),
  'IND': CountryInfo(ownerCode: 'IND', name: 'India', flag: '🇮🇳', isoCode: 'IN'),
  'INDO': CountryInfo(ownerCode: 'INDO', name: 'Indonesia', flag: '🇮🇩', isoCode: 'ID'),
  'IRAN': CountryInfo(ownerCode: 'IRAN', name: 'Iran', flag: '🇮🇷', isoCode: 'IR'),
  'IRAQ': CountryInfo(ownerCode: 'IRAQ', name: 'Iraq', flag: '🇮🇶', isoCode: 'IQ'),
  'IRL': CountryInfo(ownerCode: 'IRL', name: 'Ireland', flag: '🇮🇪', isoCode: 'IE'),
  'ISRA': CountryInfo(ownerCode: 'ISRA', name: 'Israel', flag: '🇮🇱', isoCode: 'IL'),
  'IT': CountryInfo(ownerCode: 'IT', name: 'Italy', flag: '🇮🇹', isoCode: 'IT'),
  'JPN': CountryInfo(ownerCode: 'JPN', name: 'Japan', flag: '🇯🇵', isoCode: 'JP'),
  'KAZ': CountryInfo(ownerCode: 'KAZ', name: 'Kazakhstan', flag: '🇰🇿', isoCode: 'KZ'),
  'KEN': CountryInfo(ownerCode: 'KEN', name: 'Kenya', flag: '🇰🇪', isoCode: 'KE'),
  'LAOS': CountryInfo(ownerCode: 'LAOS', name: 'Laos', flag: '🇱🇦', isoCode: 'LA'),
  'LKA': CountryInfo(ownerCode: 'LKA', name: 'Sri Lanka', flag: '🇱🇰', isoCode: 'LK'),
  'LTU': CountryInfo(ownerCode: 'LTU', name: 'Lithuania', flag: '🇱🇹', isoCode: 'LT'),
  'LUXE': CountryInfo(ownerCode: 'LUXE', name: 'Luxembourg', flag: '🇱🇺', isoCode: 'LU'),
  'MA': CountryInfo(ownerCode: 'MA', name: 'Morocco', flag: '🇲🇦', isoCode: 'MA'),
  'MALA': CountryInfo(ownerCode: 'MALA', name: 'Malaysia', flag: '🇲🇾', isoCode: 'MY'),
  'MCO': CountryInfo(ownerCode: 'MCO', name: 'Monaco', flag: '🇲🇨', isoCode: 'MC'),
  'MDA': CountryInfo(ownerCode: 'MDA', name: 'Moldova', flag: '🇲🇩', isoCode: 'MD'),
  'MEX': CountryInfo(ownerCode: 'MEX', name: 'Mexico', flag: '🇲🇽', isoCode: 'MX'),
  'MMR': CountryInfo(ownerCode: 'MMR', name: 'Myanmar', flag: '🇲🇲', isoCode: 'MM'),
  'MNE': CountryInfo(ownerCode: 'MNE', name: 'Montenegro', flag: '🇲🇪', isoCode: 'ME'),
  'MNG': CountryInfo(ownerCode: 'MNG', name: 'Mongolia', flag: '🇲🇳', isoCode: 'MN'),
  'MUS': CountryInfo(ownerCode: 'MUS', name: 'Mauritius', flag: '🇲🇺', isoCode: 'MU'),
  'NETH': CountryInfo(ownerCode: 'NETH', name: 'Netherlands', flag: '🇳🇱', isoCode: 'NL'),
  'NIG': CountryInfo(ownerCode: 'NIG', name: 'Nigeria', flag: '🇳🇬', isoCode: 'NG'),
  'NKOR': CountryInfo(ownerCode: 'NKOR', name: 'North Korea', flag: '🇰🇵', isoCode: 'KP'),
  'NOR': CountryInfo(ownerCode: 'NOR', name: 'Norway', flag: '🇳🇴', isoCode: 'NO'),
  'NPL': CountryInfo(ownerCode: 'NPL', name: 'Nepal', flag: '🇳🇵', isoCode: 'NP'),
  'NZ': CountryInfo(ownerCode: 'NZ', name: 'New Zealand', flag: '🇳🇿', isoCode: 'NZ'),
  'PAKI': CountryInfo(ownerCode: 'PAKI', name: 'Pakistan', flag: '🇵🇰', isoCode: 'PK'),
  'PERU': CountryInfo(ownerCode: 'PERU', name: 'Peru', flag: '🇵🇪', isoCode: 'PE'),
  'POL': CountryInfo(ownerCode: 'POL', name: 'Poland', flag: '🇵🇱', isoCode: 'PL'),
  'POR': CountryInfo(ownerCode: 'POR', name: 'Portugal', flag: '🇵🇹', isoCode: 'PT'),
  'PRC': CountryInfo(ownerCode: 'PRC', name: 'China', flag: '🇨🇳', isoCode: 'CN'),
  'PRY': CountryInfo(ownerCode: 'PRY', name: 'Paraguay', flag: '🇵🇾', isoCode: 'PY'),
  'QAT': CountryInfo(ownerCode: 'QAT', name: 'Qatar', flag: '🇶🇦', isoCode: 'QA'),
  'ROC': CountryInfo(ownerCode: 'ROC', name: 'Taiwan', flag: '🇹🇼', isoCode: 'TW'),
  'ROM': CountryInfo(ownerCode: 'ROM', name: 'Romania', flag: '🇷🇴', isoCode: 'RO'),
  'RP': CountryInfo(ownerCode: 'RP', name: 'Philippines', flag: '🇵🇭', isoCode: 'PH'),
  'RWA': CountryInfo(ownerCode: 'RWA', name: 'Rwanda', flag: '🇷🇼', isoCode: 'RW'),
  'SAFR': CountryInfo(ownerCode: 'SAFR', name: 'South Africa', flag: '🇿🇦', isoCode: 'ZA'),
  'SAUD': CountryInfo(ownerCode: 'SAUD', name: 'Saudi Arabia', flag: '🇸🇦', isoCode: 'SA'),
  'SDN': CountryInfo(ownerCode: 'SDN', name: 'Sudan', flag: '🇸🇩', isoCode: 'SD'),
  'SEN': CountryInfo(ownerCode: 'SEN', name: 'Senegal', flag: '🇸🇳', isoCode: 'SN'),
  'SING': CountryInfo(ownerCode: 'SING', name: 'Singapore', flag: '🇸🇬', isoCode: 'SG'),
  'SKOR': CountryInfo(ownerCode: 'SKOR', name: 'South Korea', flag: '🇰🇷', isoCode: 'KR'),
  'SLB': CountryInfo(ownerCode: 'SLB', name: 'Solomon Islands', flag: '🇸🇧', isoCode: 'SB'),
  'SPN': CountryInfo(ownerCode: 'SPN', name: 'Spain', flag: '🇪🇸', isoCode: 'ES'),
  'SVN': CountryInfo(ownerCode: 'SVN', name: 'Slovenia', flag: '🇸🇮', isoCode: 'SI'),
  'SWED': CountryInfo(ownerCode: 'SWED', name: 'Sweden', flag: '🇸🇪', isoCode: 'SE'),
  'SWTZ': CountryInfo(ownerCode: 'SWTZ', name: 'Switzerland', flag: '🇨🇭', isoCode: 'CH'),
  'THAI': CountryInfo(ownerCode: 'THAI', name: 'Thailand', flag: '🇹🇭', isoCode: 'TH'),
  'TUN': CountryInfo(ownerCode: 'TUN', name: 'Tunisia', flag: '🇹🇳', isoCode: 'TN'),
  'TURK': CountryInfo(ownerCode: 'TURK', name: 'Türkiye', flag: '🇹🇷', isoCode: 'TR'),
  'UAE': CountryInfo(ownerCode: 'UAE', name: 'United Arab Emirates', flag: '🇦🇪', isoCode: 'AE'),
  'UK': CountryInfo(ownerCode: 'UK', name: 'United Kingdom', flag: '🇬🇧', isoCode: 'GB'),
  'UKR': CountryInfo(ownerCode: 'UKR', name: 'Ukraine', flag: '🇺🇦', isoCode: 'UA'),
  'URY': CountryInfo(ownerCode: 'URY', name: 'Uruguay', flag: '🇺🇾', isoCode: 'UY'),
  'US': CountryInfo(ownerCode: 'US', name: 'United States', flag: '🇺🇸', isoCode: 'US'),
  'VAT': CountryInfo(ownerCode: 'VAT', name: 'Vatican City', flag: '🇻🇦', isoCode: 'VA'),
  'VENZ': CountryInfo(ownerCode: 'VENZ', name: 'Venezuela', flag: '🇻🇪', isoCode: 'VE'),
  'VTNM': CountryInfo(ownerCode: 'VTNM', name: 'Vietnam', flag: '🇻🇳', isoCode: 'VN'),
  'ZWE': CountryInfo(ownerCode: 'ZWE', name: 'Zimbabwe', flag: '🇿🇼', isoCode: 'ZW'),

  // Joint missions
  'CHBZ': CountryInfo(ownerCode: 'CHBZ', name: 'China / Brazil', flag: '🇨🇳🇧🇷'),
  'CHTU': CountryInfo(ownerCode: 'CHTU', name: 'China / Türkiye', flag: '🇨🇳🇹🇷'),
  'FGER': CountryInfo(ownerCode: 'FGER', name: 'France / Germany', flag: '🇫🇷🇩🇪'),
  'FRIT': CountryInfo(ownerCode: 'FRIT', name: 'France / Italy', flag: '🇫🇷🇮🇹'),
  'GRSA': CountryInfo(ownerCode: 'GRSA', name: 'Greece / Saudi Arabia', flag: '🇬🇷🇸🇦'),
  'PRES': CountryInfo(ownerCode: 'PRES', name: 'China / ESA', flag: '🇨🇳🇪🇺'),
  'SGJP': CountryInfo(ownerCode: 'SGJP', name: 'Singapore / Japan', flag: '🇸🇬🇯🇵'),
  'STCT': CountryInfo(ownerCode: 'STCT', name: 'Singapore / Taiwan', flag: '🇸🇬🇹🇼'),
  'TMMC': CountryInfo(ownerCode: 'TMMC', name: 'Turkmenistan / Monaco', flag: '🇹🇲🇲🇨'),
  'USBZ': CountryInfo(ownerCode: 'USBZ', name: 'United States / Brazil', flag: '🇺🇸🇧🇷'),

  // Special / non-country
  'CIS': CountryInfo(ownerCode: 'CIS', name: 'CIS (former USSR)', flag: '🇷🇺', isoCode: 'RU'),
  'ISS': CountryInfo(ownerCode: 'ISS', name: 'International Space Station', flag: '🛰️'),
  'UNK': CountryInfo(ownerCode: 'UNK', name: 'Unknown', flag: '❓'),
  'TBD': CountryInfo(ownerCode: 'TBD', name: 'To Be Determined', flag: '❓'),

  // Organisations
  'ESA': CountryInfo(ownerCode: 'ESA', name: 'European Space Agency', flag: '🇪🇺', isoCode: 'EU'),
  'ESRO': CountryInfo(ownerCode: 'ESRO', name: 'ESRO', flag: '🇪🇺', isoCode: 'EU'),
  'EUME': CountryInfo(ownerCode: 'EUME', name: 'EUMETSAT', flag: '🌍'),
  'EUTE': CountryInfo(ownerCode: 'EUTE', name: 'Eutelsat', flag: '🌍'),
  'NATO': CountryInfo(ownerCode: 'NATO', name: 'NATO', flag: '🏳️'),
  'ITSO': CountryInfo(ownerCode: 'ITSO', name: 'Intelsat', flag: '🌍'),
  'IM': CountryInfo(ownerCode: 'IM', name: 'Inmarsat', flag: '🌍'),
  'SEAL': CountryInfo(ownerCode: 'SEAL', name: 'Sea Launch', flag: '🚀'),

  // Commercial operators
  'AB': CountryInfo(ownerCode: 'AB', name: 'Arabsat', flag: '🛰️'),
  'ABS': CountryInfo(ownerCode: 'ABS', name: 'Asia Broadcast Satellite', flag: '🛰️'),
  'AC': CountryInfo(ownerCode: 'AC', name: 'AsiaSat', flag: '🛰️'),
  'GLOB': CountryInfo(ownerCode: 'GLOB', name: 'Globalstar', flag: '🛰️'),
  'IRID': CountryInfo(ownerCode: 'IRID', name: 'Iridium', flag: '🛰️'),
  'ISRO': CountryInfo(ownerCode: 'ISRO', name: 'ISRO', flag: '🇮🇳', isoCode: 'IN'),
  'NICO': CountryInfo(ownerCode: 'NICO', name: 'New ICO', flag: '🛰️'),
  'O3B': CountryInfo(ownerCode: 'O3B', name: 'O3b Networks', flag: '🛰️'),
  'ORB': CountryInfo(ownerCode: 'ORB', name: 'ORBCOMM', flag: '🛰️'),
  'RASC': CountryInfo(ownerCode: 'RASC', name: 'RascomStar-QAF', flag: '🛰️'),
  'SES': CountryInfo(ownerCode: 'SES', name: 'SES', flag: '🛰️'),
};

/// Look up country / organisation info for a CelesTrak OWNER code.
CountryInfo lookupOwner(String ownerCode) {
  final key = ownerCode.trim().toUpperCase();
  return _ownerMap[key] ??
      CountryInfo(ownerCode: ownerCode, name: ownerCode, flag: '❓');
}
