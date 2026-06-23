# Build tooling for the Cloud deployment deliverable.
#   make pdf  -> render ARCHITECTURE.md (with Mermaid diagrams) to PDF
#   make zip  -> bundle the ZIP deliverable (k8s manifests + PDF + READMEs)
#   make validate -> client-side validation of the manifests (needs kubectl/kustomize)

DOC      := ARCHITECTURE
PDF      := $(DOC).pdf
ZIPNAME  := neon-beat-cloud-deliverable.zip

.PHONY: pdf zip validate clean

# Requires: pandoc, a LaTeX engine (xelatex), and mermaid-filter
# (npm i -g @mermaid-js/mermaid-cli mermaid-filter)
pdf: $(PDF)

$(PDF): $(DOC).md
	pandoc $(DOC).md \
		-F mermaid-filter \
		--pdf-engine=xelatex \
		-V mainfont="DejaVu Sans" \
		-o $(PDF)

# Bundle the ZIP deliverable. Builds the PDF first so it is included.
zip: pdf
	rm -f $(ZIPNAME)
	zip -r $(ZIPNAME) k8s README.md k8s/README.md $(PDF) -x '*.DS_Store'

# Client-side sanity check of the manifests (no cluster needed).
validate:
	kubectl kustomize k8s > /dev/null && echo "kustomize build OK"

clean:
	rm -f $(PDF) $(ZIPNAME) mermaid-filter.err
