<a href="https://www.islas.org.mx"><img src="https://www.islas.org.mx/img/logo.svg" align="right" width="256" /></a>

# Maritime Informatics

![example branch parameter](https://github.com/IslasGECI/maritime_informatics/actions/workflows/actions.yml/badge.svg)
![licencia](https://img.shields.io/github/license/IslasGECI/maritime_informatics)
![languages](https://img.shields.io/github/languages/top/IslasGECI/maritime_informatics)
![commits](https://img.shields.io/github/commit-activity/y/IslasGECI/maritime_informatics)

Analyze vessel traffic around Brittany ports. Generate Voronoi diagrams
that reveal which port is closest to any point at sea and detect vessel
stop patterns near mooring areas.

## What you can do

- **See port influence zones**: A map showing which maritime areas are
  closest to each port in Brittany
- **Track vessel movements**: Import AIS position data to analyze where
  ships travel and stop
- **Detect stop patterns**: Identify areas outside ports where vessels
  linger, such as mooring zones

## How to use it

```bash
docker compose run --name maritime_informatics_ci --rm islasgeci
```

Then run:

```bash
# Generate the complete Voronoi map
docker exec maritime_informatics_ci make all

# Or import vessel data and compute stop segments
docker exec maritime_informatics_ci make compute_vessel_segments
```

The output map is saved to `reports/figures/voronoi_map.png`.

## Before you start

- Install Docker and Docker Compose on your machine
- The `data` service downloads maritime datasets automatically on first
  run

## Coming soon

- Clustering of vessel stops to identify mooring areas outside ports
- Docking area detection within ports using stop density analysis
- Multi-layer thematic maps combining traffic, ports, and protected areas
