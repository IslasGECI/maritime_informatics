<a href="https://www.islas.org.mx"><img src="https://www.islas.org.mx/img/logo.svg" align="right" width="256" /></a>

# Maritime Informatics

![example branch
parameter](https://github.com/IslasGECI/maritime_informatics/actions/workflows/actions.yml/badge.svg)
![licencia](https://img.shields.io/github/license/IslasGECI/maritime_informatics)
![languages](https://img.shields.io/github/languages/top/IslasGECI/maritime_informatics)
![commits](https://img.shields.io/github/commit-activity/y/IslasGECI/maritime_informatics)

## Description

Geospatial pipeline for maritime data analysis. Generates Voronoi tessellations
from port locations using PostGIS and renders thematic maps with GMT.

## Key Technologies

- **PostgreSQL/PostGIS** for spatial data and Voronoi computation
- **GMT** for cartographic rendering
- **GDAL/OGR** for vector data conversion
- **Docker** for containerized development

## Prerequisites

- Docker and Docker Compose (for containerized development)

## Usage

```bash
docker compose run --name maritime_informatics_ci --rm islasgeci
docker exec maritime_informatics_ci make
```

## References

Data sources and methodologies informed by [maritime-informatics.com](http://maritime-informatics.com).
