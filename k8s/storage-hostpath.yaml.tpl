apiVersion: v1
kind: PersistentVolume
metadata:
  name: spot-render-storage
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: hostpath
  hostPath:
    path: ${HOST_STORAGE_ROOT}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: spot-render-storage
  namespace: spot-render
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  volumeName: spot-render-storage
  storageClassName: hostpath
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: spot-render-storage
  namespace: rendering
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  volumeName: spot-render-storage
  storageClassName: hostpath
