!
! Copyright (C) 2001 PWSCF group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-----------------------------------------------------------------------
subroutine mix_potential (ndim, vout, vin, alphamix, dr2, tr2, &
     iter, n_iter, filename, conv)
  !-----------------------------------------------------------------------
  !
  ! Modified Broyden's method for potential/charge density mixing
  !             D.D.Johnson, PRB 38, 12807 (1988)
  ! On input :
  !    ndim      dimension of arrays vout, vin
  !    vout      output potential/rho at current iteration 
  !    vin       potential/rho at previous iteration
  !    alphamix  mixing factor (0 < alphamix <= 1)
  !    tr2       threshold for selfconsistency
  !    iter      current iteration number
  !    n_iter    number of iterations used in the mixing
  !    filename  if present save previous iterations on file 'filename'
  !              otherwise keep everything in memory
  ! On output:
  !    dr2       [(vout-vin)/ndim]^2
  !    vin       mixed potential
  !    vout      vout-vin
  !    conv      true if dr2.le.tr2
#include "machine.h"
  use parameters, only : DP
  use allocate 
  implicit none  
  !
  !   First the dummy variables
  ! 
  character (len=42) :: filename
  integer :: ndim, iter, n_iter
  real(kind=DP) :: vout (ndim), vin (ndim), alphamix, dr2, tr2  
  logical :: conv  
  !
  !   Here the local variables
  !
  ! max number of iterations used in mixing: n_iter must be .le. maxter
  integer :: maxter
  parameter (maxter = 8)  
  !
  integer :: iunit, iunmix, n, i, j, iwork (maxter), info, iter_used, &
       ipos, inext, ndimtot  
  ! work space containing info from previous iterations:
  ! must be kept in memory and saved between calls if filename=' '
  real(kind=DP), pointer, save :: df (:,:), dv (:,:) 
  !
  real(kind=DP), pointer :: vinsave (:)
  real(kind=DP) :: beta (maxter, maxter), gamma, work (maxter), norm
  logical :: saveonfile, opnd, exst  
  real(kind=DP) :: DDOT, DNRM2  
  external DDOT, DNRM2
  ! adjustable parameters as suggested in the original paper
  real(kind=DP) w (maxter), w0
  data w0 / 0.01d0 /, w / maxter * 1.d0 /  
  !
  !
  call start_clock ('mix_pot')  
  if (iter.lt.1) call error ('mix_potential', 'iter is wrong', 1)  
  if (n_iter.gt.maxter) call error ('mix_potential', 'n_iter too big', 1)
  if (ndim.le.0) call error ('mix_potential', 'ndim .le. 0', 3)  
  !
  saveonfile = filename.ne.' '  
  !
  do n = 1, ndim  
     vout (n) = vout (n) - vin (n)  
  enddo
  dr2 = DNRM2 (ndim, vout, 1) **2  
  ndimtot = ndim  
#ifdef PARA
  call reduce (1, dr2)  
  call ireduce (1, ndimtot)  
#endif
  dr2 = (sqrt (dr2) / ndimtot) **2  

  conv = dr2.lt.tr2  
  if (saveonfile) then  
     do iunit = 99, 1, - 1  
        inquire (unit = iunit, opened = opnd)  
        iunmix = iunit  
        if (.not.opnd) goto 10  
     enddo
     call error ('mix_potential', 'free unit not found?!?', 1)  
10   continue  
     if (conv) then
        ! remove temporary file (open and close it)
        call diropn (iunmix, filename, ndim, exst)
        close (unit=iunmix, status='delete')
        call stop_clock ('mix_pot')  
        return  
     endif
     call diropn (iunmix, filename, ndim, exst)  
     if (iter.gt.1.and..not.exst) then
        call error ('mix_potential', 'file not found, restarting', -1)
        iter = 1  
     endif
     call mallocate(df, ndim , n_iter)  
     call mallocate(dv, ndim , n_iter)  
  else  
     if (iter.eq.1) then  
        call mallocate(df, ndim , n_iter)   
        call mallocate(dv, ndim , n_iter) 
     endif
     if (conv) then  
        call mfree (dv)  
        call mfree (df)  
        call stop_clock ('mix_pot')  
        return  
     endif
     call mallocate(vinsave, ndim)  
  endif
  !
  ! iter_used = iter-1  if iter <= n_iter
  ! iter_used = n_iter  if iter >  n_iter
  !
  iter_used = min (iter - 1, n_iter)  
  !
  ! ipos is the position in which results from the present iteraction
  ! are stored. ipos=iter-1 until ipos=n_iter, then back to 1,2,...
  !
  ipos = iter - 1 - ( (iter - 2) / n_iter) * n_iter  
  !
  if (iter.gt.1) then  
     if (saveonfile) then  
        call davcio (df (1, ipos), ndim, iunmix, 1, - 1)  
        call davcio (dv (1, ipos), ndim, iunmix, 2, - 1)  
     endif
     do n = 1, ndim  
        df (n, ipos) = vout (n) - df (n, ipos)  
        dv (n, ipos) = vin (n) - dv (n, ipos)  
     enddo
     norm = (DNRM2 (ndim, df (1, ipos), 1) ) **2  
#ifdef PARA
     call reduce (1, norm)  
#endif
     norm = sqrt (norm)  
     call DSCAL (ndim, 1.d0 / norm, df (1, ipos), 1)  
     call DSCAL (ndim, 1.d0 / norm, dv (1, ipos), 1)  
  endif
  !
  if (saveonfile) then  
     do i = 1, iter_used  
        if (i.ne.ipos) then  
           call davcio (df (1, i), ndim, iunmix, 2 * i + 1, - 1)  
           call davcio (dv (1, i), ndim, iunmix, 2 * i + 2, - 1)  
        endif
     enddo
     call davcio (vout, ndim, iunmix, 1, 1)  
     call davcio (vin, ndim, iunmix, 2, 1)  
     if (iter.gt.1) then  
        call davcio (df (1, ipos), ndim, iunmix, 2 * ipos + 1, 1)  
        call davcio (dv (1, ipos), ndim, iunmix, 2 * ipos + 2, 1)  
     endif
  else  
     call DCOPY (ndim, vin, 1, vinsave, 1)  
  endif
  !
  do i = 1, iter_used  
     do j = i + 1, iter_used  
        beta (i, j) = w (i) * w (j) * DDOT (ndim, df (1, j), 1, df (1, i), 1)
#ifdef PARA
        call reduce (1, beta (i, j) )  
#endif
     enddo
     beta (i, i) = w0**2 + w (i) **2  
  enddo
  !
  call DSYTRF ('u', iter_used, beta, maxter, iwork, work, maxter, info)
  call error ('broyden', 'factorization', info)  
  call DSYTRI ('u', iter_used, beta, maxter, iwork, work, info)  
  call error ('broyden', 'DSYTRI', info)  
  !
  do i = 1, iter_used  
     do j = i + 1, iter_used  
        beta (j, i) = beta (i, j)  
     enddo
  enddo
  !
  do i = 1, iter_used  
     work (i) = DDOT (ndim, df (1, i), 1, vout, 1)  
  enddo
#ifdef PARA
  call reduce (iter_used, work)  
#endif
  !
  do n = 1, ndim  
     vin (n) = vin (n) + alphamix * vout (n)  
  enddo
  !
  do i = 1, iter_used  
     gamma = 0.d0  
     do j = 1, iter_used  
        gamma = gamma + beta (j, i) * w (j) * work (j)  
     enddo
     !
     do n = 1, ndim  
        vin (n) = vin (n) - w (i) * gamma * (alphamix * df (n, i) + dv (n, i) )
     enddo
  enddo
  !
  if (saveonfile) then 
     close (iunmix, status='keep')
     call mfree(dv)  
     call mfree(df)  
  else
     inext = iter - ( (iter - 1) / n_iter) * n_iter  
     call DCOPY (ndim, vout, 1, df (1, inext), 1)  
     call DCOPY (ndim, vinsave, 1, dv (1, inext), 1)  
     call mfree(vinsave)  
  endif
  call stop_clock ('mix_pot')  
  return  
end subroutine mix_potential

