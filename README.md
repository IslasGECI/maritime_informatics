<a href="https://www.islas.org.mx"><img src="https://www.islas.org.mx/img/logo.svg" align="right" width="256" /></a>

# Maritime Informatics

![example branch parameter](https://github.com/IslasGECI/maritime_informatics/actions/workflows/actions.yml/badge.svg)
![licencia](https://img.shields.io/github/license/IslasGECI/maritime_informatics)
![languages](https://img.shields.io/github/languages/top/IslasGECI/maritime_informatics)
![commits](https://img.shields.io/github/commit-activity/y/IslasGECI/maritime_informatics)

Analyze vessel traffic around Brittany ports. Generate three maps that
reveal port influence zones, vessel stop clusters near mooring areas, and
the shape of those mooring zones.

## What you can do

- **Port influence zones** — A Voronoi map showing which maritime areas are
  closest to each port in Brittany
- **Stop clusters** — A map of the Port of Brest showing where vessels
  linger outside the port, with each cluster colored by ID
- **Mooring zone shapes** — A convex hulls map of the same area showing the
  precise shape, centroid, and vessel count of each mooring cluster

## How to use it

Run the container and generate all three maps:

```bash
docker compose run --name maritime_informatics_ci --rm islasgeci
docker exec maritime_informatics_ci make all
```

Outputs are saved to `reports/figures/`:
- `voronoi_map.png` — Port influence zones across Brittany
- `cluster_map.png` — Vessel stop clusters at the Port of Brest
- `brest_hulls.png` — Convex hulls enclosing each stop cluster

## Before you start

- Install Docker and Docker Compose
- The `data` service downloads maritime datasets automatically on first run

## Coming soon

- Docking area detection within ports using stop density analysis
- Multi-layer thematic maps combining traffic, ports, and protected areas
