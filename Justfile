KN := "kubectl -n $NAMESPACE"
NAMESPACE := "vllm-clusterscale"


exec:
  kubectl cp run.sh {{NAMESPACE}}/ibgda-repro:/app/run.sh \
  && kubectl exec -it ibgda-repro -- /bin/bash
