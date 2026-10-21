import { defineConfig } from '@neon/config/v1';
export default defineConfig({
  buckets: {
    'anatomy-models': {}, 'medical-images': {},
    'offline-packs': {}, 'source-media': {},
  },
  functions: { api: { name: 'Dawa & Hayah public educational API', source: 'functions/index.mjs' } },
});
