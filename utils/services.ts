export type ServiceSlug = 'bond-cleaning' | 'bathroom-deep-clean' | 'spring-cleaning';
export type ServiceDef = {
  slug: ServiceSlug;
  label: string;
  h1: (suburbName: string) => string;
};

export const SERVICES: Record<ServiceSlug, ServiceDef> = {
  'bond-cleaning': {
    slug: 'bond-cleaning',
    label: 'Bond Cleaning',
    h1: s => `Bond Cleaning in ${s}`
  },
  'bathroom-deep-clean': {
    slug: 'bathroom-deep-clean',
    label: 'Bathroom Deep Clean',
    h1: s => `Bathroom Deep Cleaning in ${s}`
  },
  'spring-cleaning': {
    slug: 'spring-cleaning',
    label: 'Spring Cleaning',
    h1: s => `Spring Cleaning in ${s}`
  }
};

export const CROSS_SERVICES_FOR: Record<ServiceSlug, ServiceSlug[]> = {
  'bond-cleaning': ['bathroom-deep-clean', 'spring-cleaning'],
  'bathroom-deep-clean': ['bond-cleaning', 'spring-cleaning'],
  'spring-cleaning': ['bond-cleaning', 'bathroom-deep-clean']
};
