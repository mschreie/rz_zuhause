

[manager]
jump ansible_connection=local

[manager-ilo]
jump-ilo

[glusterleft]
gluster11
gluster12

[glusterright]
gluster21
gluster22

[rhevleft]
rhev11
rhev12

[rhevright]
rhev21
rhev22

[gluster:children]
glusterleft
glusterright

[rhev:children]
rhevleft
rhevright

[left:children]
glusterleft
rhevleft

[right:children]
glusterright
rhevright

[servers:children]
gluster
rhev

[glusterleft-ilo]
gluster11-ilo
gluster12-ilo

[glusterright-ilo]
gluster21-ilo
gluster22-ilo

[rhevleft-ilo]
rhev11-ilo
rhev12-ilo

[rhevright-ilo]
rhev21-ilo
rhev22-ilo

[gluster-ilo:children]
glusterleft-ilo
glusterright-ilo

[rhev-ilo:children]
rhevleft-ilo
rhevright-ilo

[left-ilo:children]
glusterleft-ilo
rhevleft-ilo

[right-ilo:children]
glusterright-ilo
rhevright-ilo

[servers-ilo:children]
gluster-ilo
rhev-ilo

