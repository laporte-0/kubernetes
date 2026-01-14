# Challenge 5 – Accès à Kubernetes

- Installation de `kubectl`
- Configuration du fichier kubeconfig depuis Rancher (cluster **net4255**)
- Connexion au cluster vérifiée avec la commande `kubectl cluster-info`
- Problème TLS résolu à l’aide de la configuration fournie par Rancher

Commandes utilisées :
- `kubectl cluster-info`

## Challenge 6 – First Kubernetes Pod (CLI)

- Deployment `webnodb` created via kubectl
- 1 replica only
- No Service created
- Pod running in namespace `azaabar`
- Access tested using port-forwarding

Commands used:
- kubectl create deployment
- kubectl get deployments -o wide
- kubectl get pods -o wide
- kubectl port-forward
