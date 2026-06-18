import { collectionCardDefinitions, resolveCollectionCards, resolveMetaCollections } from '../collectionCards';
import type { CollectionCardData } from '../collectionCards';
import * as fs from 'fs';
import * as path from 'path';
import * as yaml from 'js-yaml';

const collectionsDir =
  process.env.COLLECTIONS_DIR ??
  path.resolve(__dirname, '../../../../../collections');

interface ManifestCollection {
  itemCount?: number;
}

interface CoreManifest {
  collections: Record<string, ManifestCollection>;
}

function loadCoreManifest(): CoreManifest {
  const manifestPath = path.join(collectionsDir, 'core-manifest.yml');
  const content = fs.readFileSync(manifestPath, 'utf-8');
  return yaml.load(content) as CoreManifest;
}

const manifest = loadCoreManifest();

function getArtifactCount(collectionName: string): number {
  if (collectionName === 'hve-core-all') {
    // Sum all collection itemCounts for hve-core-all
    return Object.values(manifest.collections).reduce(
      (sum, col) => sum + (col.itemCount ?? 0),
      0,
    );
  }
  return manifest.collections[collectionName]?.itemCount ?? 0;
}

const counts = Object.fromEntries(
  [...collectionCardDefinitions.map((c) => c.name), 'hve-core-all'].map(
    (name) => [name, getArtifactCount(name)],
  ),
);
const collectionCards = resolveCollectionCards(counts);
const metaCollections = resolveMetaCollections(counts);

describe('collectionCards', () => {
  const expectedNames = [
    'ado',
    'coding-standards',
    'data-science',
    'design-thinking',
    'github',
    'hve-core',
    'project-planning',
    'security',
  ];

  it('contains all expected collections', () => {
    const names = collectionCards.map((c) => c.name);
    expect(names).toEqual(expect.arrayContaining(expectedNames));
    expect(names).toHaveLength(expectedNames.length);
  });

  it('has unique names', () => {
    const names = collectionCards.map((c) => c.name);
    expect(new Set(names).size).toBe(names.length);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a non-empty description', (_name, card) => {
    expect(card.description.length).toBeGreaterThan(0);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a positive integer artifact count', (_name, card) => {
    expect(Number.isInteger(card.artifacts)).toBe(true);
    expect(card.artifacts).toBeGreaterThan(0);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a valid maturity value', (_name, card) => {
    expect(['Stable', 'Preview', 'Experimental']).toContain(card.maturity);
  });

  it.each(
    collectionCards.map((c): [string, CollectionCardData] => [c.name, c]),
  )('%s has a non-empty href', (_name, card) => {
    expect(card.href.length).toBeGreaterThan(0);
  });
});

describe('metaCollections', () => {
  it('contains hve-core-all entry', () => {
    expect(metaCollections).toHaveProperty('hve-core-all');
  });

  it('has positive integer values', () => {
    for (const [, value] of Object.entries(metaCollections)) {
      expect(Number.isInteger(value)).toBe(true);
      expect(value).toBeGreaterThan(0);
    }
  });
});

describe('artifact count cross-validation', () => {
  it.each(collectionCards.map((c): [string] => [c.name]))(
    '%s artifact count matches core-manifest.yml itemCount',
    (name) => {
      const card = collectionCards.find((c) => c.name === name)!;
      const manifestCount = getArtifactCount(name);
      expect(card.artifacts).toBe(manifestCount);
    },
  );

  it('hve-core-all count matches sum of all collection itemCounts', () => {
    const manifestCount = getArtifactCount('hve-core-all');
    expect(metaCollections['hve-core-all']).toBe(manifestCount);
  });
});
