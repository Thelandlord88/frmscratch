#!/usr/bin/env node
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const ROOT = path.resolve(process.cwd());

async function run() {
  console.log('🔍 Checking adjacency vs cluster integrity...\n');

  let clusters = {};
  let adjacency = {};

  // Load data files
  try {
    const clustersPath = path.join(ROOT, 'src/content/areas.clusters.json');
    if (existsSync(clustersPath)) {
      clusters = JSON.parse(readFileSync(clustersPath, 'utf-8'));
    } else {
      console.error('❌ areas.clusters.json not found');
      process.exit(1);
    }

  const adjacencyPath = path.join(ROOT, 'src/content/areas.adj.json');
    if (existsSync(adjacencyPath)) {
      adjacency = JSON.parse(readFileSync(adjacencyPath, 'utf-8'));
    } else {
      console.error('❌ adjacency.json not found');
      process.exit(1);
    }
  } catch (e) {
    console.error('❌ Could not load cluster or adjacency data:', e);
    process.exit(1);
  }

  // Build suburb -> cluster map
  const suburb2cluster = new Map();
  const allSuburbs = new Set();
  const duplicates = [];
  
  function slugify(name) {
    if (name == null) return '';
    const raw = typeof name === 'string' ? name : (name.slug || name.name || '');
    return String(raw).toLowerCase()
      .replace(/\s+/g, '-')
      .replace(/[^a-z0-9-]/g, '');
  }
  
  const clustersList = clusters.clusters || [];
  for (const cluster of clustersList) {
    const suburbs = cluster.suburbs || [];
    for (const suburbName of suburbs) {
      const slug = slugify(suburbName);
      if (suburb2cluster.has(slug)) {
        duplicates.push(slug);
        console.error(`❌ Duplicate suburb: ${slug} appears in multiple clusters`);
      }
      suburb2cluster.set(slug, cluster.slug);
      allSuburbs.add(slug);
    }
  }

  console.log(`📊 Total clusters: ${clustersList.length}`);
  console.log(`📊 Total suburbs: ${allSuburbs.size}`);
  console.log(`📊 Adjacency entries: ${Object.keys(adjacency).length}`);
  if (duplicates.length > 0) {
    console.log(`📊 Duplicate suburbs: ${duplicates.length}`);
  }
  console.log();

  let missing = 0;
  let crossCluster = 0;
  const crossClusterEdges = [];
  const missingSuburbs = [];

  // Check adjacency integrity
  for (const [from, data] of Object.entries(adjacency)) {
    if (!suburb2cluster.has(from)) {
      console.error(`❌ Missing suburb in clusters: ${from}`);
      missingSuburbs.push(from);
      missing++;
      continue;
    }

    const fromCluster = suburb2cluster.get(from);
  const neighbors = Array.isArray(data) ? data : (data.adjacent_suburbs || []);
    
    for (const to of neighbors) {
      if (!suburb2cluster.has(to)) {
        console.error(`❌ Missing neighbor in clusters: ${from} -> ${to}`);
        missingSuburbs.push(to);
        missing++;
        continue;
      }

      const toCluster = suburb2cluster.get(to);
      if (fromCluster !== toCluster) {
        crossClusterEdges.push({ from, to, fromCluster, toCluster });
        crossCluster++;
      }
    }
  }

  if (crossClusterEdges.length > 0) {
    console.log(`⚠️  Cross-cluster edges found (${crossClusterEdges.length}):`);
    crossClusterEdges.slice(0, 10).forEach(edge => {
      console.log(`  ${edge.from}(${edge.fromCluster}) -> ${edge.to}(${edge.toCluster})`);
    });
    if (crossClusterEdges.length > 10) {
      console.log(`  ... and ${crossClusterEdges.length - 10} more`);
    }
    console.log();
  }

  // Summary stats by cluster
  console.log('📊 Cluster breakdown:');
  for (const cluster of clustersList) {
    const clusterSuburbs = cluster.suburbs.map(name => slugify(name));
    const adjacentCount = clusterSuburbs.filter(s => adjacency[s]).length;
    console.log(`  ${cluster.slug}: ${clusterSuburbs.length} suburbs, ${adjacentCount} with adjacency data`);
  }
  console.log();

  if (missing > 0 || duplicates.length > 0) {
    console.error(`❌ Graph-data integrity FAILED: missing=${missing}, duplicates=${duplicates.length}`);
    if (missingSuburbs.length > 0) {
      console.error(`   Missing suburbs: ${[...new Set(missingSuburbs)].join(', ')}`);
    }
    process.exit(1);
  }

  if (crossCluster > 0) {
    console.log(`⚠️  Cross-cluster edges detected: ${crossCluster}`);
    console.log(`   This may violate same-cluster policy depending on requirements`);
    // Don't exit with error for cross-cluster edges as they might be intentional
  }

  console.log('✅ Graph data integrity OK: all adjacency nodes exist in clusters');
}

run().catch(e => {
  console.error('Error:', e);
  process.exit(1);
});
