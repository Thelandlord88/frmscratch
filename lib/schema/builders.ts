import { absoluteUrl } from '~/lib/url';

export interface LocalBusinessOptions {
  name?: string;
  url?: string;
  telephone?: string;
  image?: string;
  address?: Partial<{ locality: string; region: string; postalCode: string; country: string }>;
  areaServed?: string[];
  geo?: { lat: number; lng: number };
  opening?: { days: string[]; opens: string; closes: string }[];
}

export function buildLocalBusiness(opts: LocalBusinessOptions = {}) {
  const {
    name = 'One N Done Bond Clean',
    url = absoluteUrl('/'),
    telephone = '+61405779420',
    image = absoluteUrl('/og.jpg'),
    address = { locality: 'Redbank Plains', region: 'QLD', postalCode: '4301', country: 'AU' },
    areaServed = [],
    geo = { lat: -27.6413, lng: 152.9006 },
    opening = [ { days: ['Monday','Tuesday','Wednesday','Thursday','Friday'], opens: '08:00', closes: '18:00' } ]
  } = opts;
  return {
    '@context': 'https://schema.org',
    '@type': 'CleaningService',
    name,
    url,
    telephone,
    priceRange: '$$',
    image,
    address: {
      '@type': 'PostalAddress',
      addressLocality: address.locality,
      addressRegion: address.region,
      postalCode: address.postalCode,
      addressCountry: address.country
    },
    ...(areaServed.length ? { areaServed: areaServed.map(n => ({ '@type': 'Place', name: n })) } : {}),
    geo: { '@type': 'GeoCoordinates', latitude: geo.lat, longitude: geo.lng },
    openingHoursSpecification: opening.map(o => ({ '@type': 'OpeningHoursSpecification', dayOfWeek: o.days, opens: o.opens, closes: o.closes }))
  };
}

export function buildBreadcrumb(items: { name: string; item?: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((it, i) => ({ '@type': 'ListItem', position: i + 1, name: it.name, ...(it.item ? { item: it.item } : {}) }))
  };
}

export function buildFaq(items: { q: string; a: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'FAQPage',
    mainEntity: items.map(it => ({ '@type': 'Question', name: it.q, acceptedAnswer: { '@type': 'Answer', text: it.a } }))
  };
}

export function buildWebPage(idUrl: string) {
  return {
    '@type': 'WebPage',
    '@id': `${idUrl}#webpage`,
    url: idUrl,
    isPartOf: { '@id': absoluteUrl('/#website') }
  };
}
