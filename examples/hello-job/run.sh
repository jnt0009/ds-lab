#!/bin/bash
# The NSF's first job: proves a run gets R, Python and a place to put results ($NSF_OUT), at home or in GCP.
#   nsf-job with NSF_REPO=https://github.com/jnt0009/ds-lab NSF_CMD="bash examples/hello-job/run.sh"
set -euo pipefail
: "${NSF_OUT:=out}"; mkdir -p "$NSF_OUT"
Rscript -e '
fit <- lm(mpg ~ wt + hp, data = mtcars)
co  <- broom::tidy(fit)
readr::write_csv(co, file.path(Sys.getenv("NSF_OUT"), "mtcars_coefficients.csv"))
p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point(colour = "#0072B2") +
     ggplot2::geom_smooth(method = "lm", formula = y ~ x, colour = "#D55E00") + ggplot2::theme_minimal()
ggplot2::ggsave(file.path(Sys.getenv("NSF_OUT"), "mtcars.png"), p, width = 6, height = 4, dpi = 120, device = ragg::agg_png)
print(co)'
python - <<'PY'
import json, os, platform, sklearn, numpy as np
from sklearn.linear_model import LinearRegression
rng = np.random.default_rng(1); X = rng.normal(size=(500, 3)); y = X @ [1.5, -2.0, 0.5] + rng.normal(scale=0.1, size=500)
coef = LinearRegression().fit(X, y).coef_.round(3).tolist()
out = {"python": platform.python_version(), "sklearn": sklearn.__version__, "cpus": os.cpu_count(), "coef": coef}
json.dump(out, open(os.path.join(os.environ["NSF_OUT"], "python.json"), "w"), indent=2); print(out)
PY
