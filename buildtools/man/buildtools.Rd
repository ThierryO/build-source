% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/buildtools.R
\name{find_logo}
\alias{find_logo}
\alias{package_sysdeps_string}
\alias{vignettes_base64}
\alias{commit_info_base64}
\alias{install_dependencies}
\alias{read_description_field}
\alias{get_maintainer_info}
\alias{maintainer_info_base64}
\title{Build tools}
\usage{
find_logo(path, git_url, subdir = "")

vignettes_base64(repo, pkg = basename(repo), subdir = "")

commit_info_base64(repo = repo)

install_dependencies(path = ".")

read_description_field(field, path = ".")

get_maintainer_info(path = ".")

maintainer_info_base64(path = ".")
}
\arguments{
\item{path}{root directory of package}

\item{git_url}{of the git repository}

\item{subdir}{path within the git repo where the pkg is}

\item{repo}{path to the git repository}

\item{pkg}{name of the installed package}

\item{field}{which field from the description to show}
}
\description{
Get some extra info about packages.
}
