!
! Copyright (C) 2003 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-----------------------------------------------------------------------
subroutine generate_effective_charges_c &
     (nat,nsym,s,irt,at,bg,n_diff_sites,equiv_atoms,has_equivalent, &
      asr,nasr,zv,ityp,ntyp,atm,zstar)
  !-----------------------------------------------------------------------
  USE io_global, ONLY : stdout
  !
  ! generate all effective charges
  !
#include "f_defs.h"
  USE kinds, only : DP
  implicit none
  integer :: nat, nsym, n_diff_sites, irt(48,nat), equiv_atoms(nat,nat),&
       s(3,3,48), has_equivalent(nat), nasr
  logical :: asr      
  integer :: isym, na, ni, nj, sni, i, j, k, l
  integer :: table(48,48), invs(3,3,48)
  integer :: ityp(nat), ntyp
  real(DP) :: zstar(3,3,nat), at(3,3), bg(3,3), sumz, zv(ntyp)
  logical :: done(nat), no_equivalent_atoms
  character(3) :: atm(ntyp)
  !
  no_equivalent_atoms=.true.
  do na = 1,nat
     no_equivalent_atoms = no_equivalent_atoms .and. has_equivalent(na).eq.0
  end do
  if (no_equivalent_atoms) goto 100
  !
  !  zstar in input is in crystal axis
  !
  do na = 1,nat
     if (has_equivalent(na).eq.0 ) then
        done(na)=.true.
     else
        zstar(:,:,na) = 0.d0
        done(na)=.false.
     end if
  end do
  !
  ! recalculate S^-1 (once again)
  !
  call multable (nsym,s,table)
  call inverse_s(nsym,s,table,invs)
  !
  do isym = 1,nsym
     do na = 1,n_diff_sites
        ni = equiv_atoms(na,1)
        sni = irt(isym,ni)
        if ( .not.done(sni) ) then
           do i = 1,3
              do j = 1,3
                 do k = 1,3
                    do l = 1,3
                       zstar(i,j,sni) =  zstar(i,j,sni) +  &
                            invs(i,k,isym)*invs(j,l,isym)*zstar(k,l,ni)
                    end do
                 end do
              end do
           end do
           done(sni)=.true.
        end if
     end do
  end do

100 continue
  !
  ! return to Cartesian axis
  !
  do na = 1,nat
     call trntns(zstar(1,1,na),at,bg, 1)
  end do
  !
  ! add the diagonal part
  !
  do i = 1, 3
     do na = 1, nat
        zstar(i, i, na) = zstar (i, i, na) + zv (ityp (na) )
     enddo
  enddo
  IF (asr) THEN
     DO i=1,3
        DO j=1,3
           sumz=0.0_DP
           DO na=1,nat
              IF (na.ne.nasr) sumz=sumz+zstar(i,j,na)
           ENDDO
           zstar(i,j,nasr)=-sumz
        ENDDO
     ENDDO
  ENDIF
  !
  ! write Z_{beta}{s,alpha}on standard output
  !

  WRITE( stdout, '(/,10x,"Effective charges (d P / du) in cartesian axis ",/)' &
       &)
  ! WRITE( stdout, '(10x,  "          Z_{beta}{s,alpha} ",/)')
  do na = 1, nat
     WRITE( stdout, '(10x," atom ",i6,a6)') na, atm(ityp(na))
     WRITE( stdout, '(6x,"Px  (",3f15.5," )")')  (zstar (1, j, na), j = 1, 3) 
     WRITE( stdout, '(6x,"Py  (",3f15.5," )")')  (zstar (2, j, na), j = 1, 3) 
     WRITE( stdout, '(6x,"Pz  (",3f15.5," )")')  (zstar (3, j, na), j = 1, 3) 
  enddo
  !
  return
end subroutine generate_effective_charges_c
