<a href="https://www.islas.org.mx"><img src="https://www.islas.org.mx/img/logo.svg" align="right" width="256" /></a>

# Maritime Informatics

[![codecov](https://codecov.io/gh/IslasGECI/maritime_informatics/graph/badge.svg?token=ISI1P07QMK)](https://codecov.io/gh/IslasGECI/maritime_informatics)
![example branch
parameter](https://github.com/IslasGECI/maritime_informatics/actions/workflows/actions.yml/badge.svg)
![licencia](https://img.shields.io/github/license/IslasGECI/maritime_informatics)
![languages](https://img.shields.io/github/languages/top/IslasGECI/maritime_informatics)
![commits](https://img.shields.io/github/commit-activity/y/IslasGECI/maritime_informatics)
![R-version](https://img.shields.io/github/r-package/v/IslasGECI/maritime_informatics)

## Description

R package for maritime data analysis and processing. Provides tools for working with AIS
(Automatic Identification System) data, vessel trajectory analysis, and maritime traffic
studies.

## Key Technologies

- **R** with R6 and tidyverse
- **PostgreSQL/PostGIS** for spatial maritime data
- **Docker** for containerized development
- **testthat** for unit testing
- **styler** for code formatting

## Prerequisites

- Docker and Docker Compose (for containerized development)

## Installation

### R package

```r
devtools::install_github("IslasGECI/maritime_informatics")
```

## Usage

```bash
docker compose run --rm islasgeci
```

## References

Data sources and methodologies informed by [maritime-informatics.com](http://maritime-informatics.com).
