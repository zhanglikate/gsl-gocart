!! Kate.Zhang@noaa.gov 11/2023

module dep_wet_ls_mod

  use gsd_chem_constants, only : kind_chem, grav => con_g
  use gsd_chem_config

!  use chem_tracers_mod
!  use chem_rc_mod
!  use chem_tracers_mod
!  use chem_const_mod, only : grav => grvity

  implicit none

  ! -- large scale wet deposition scavenging factors
  !real(kind_chem), dimension(num_chem):: alpha
  private

  public :: wetdep_ls
  public :: WetRemovalGOCART

contains


  subroutine wetdep_ls(dt,var,rain,moist,rho,var_rmv,lat,       &
                       num_moist,num_chem,p_qc,p_qi,dz8w,vvel,  &
                       ids,ide, jds,jde, kds,kde,               &
                       ims,ime, jms,jme, kms,kme,               &
                       its,ite, jts,jte, kts,kte                )
    IMPLICIT NONE

    INTEGER,      INTENT(IN   ) :: num_chem,num_moist,p_qc, p_qi,    &
                                   ids,ide, jds,jde, kds,kde,      &
                                   ims,ime, jms,jme, kms,kme,               &
                                   its,ite, jts,jte, kts,kte
    real(kind_chem), INTENT(IN ) :: dt
    REAL(kind_chem), DIMENSION( ims:ime, kms:kme, jms:jme, 1:num_moist ),                &
          INTENT(IN ) ::                                   moist
    REAL(kind_chem),  DIMENSION( ims:ime , kms:kme , jms:jme ),                        &
           INTENT(IN   ) :: rho,dz8w,vvel
    REAL(kind_chem),  DIMENSION( ims:ime , kms:kme , jms:jme ,1:num_chem),             &
           INTENT(INOUT) :: var
    REAL(kind_chem),  DIMENSION( ims:ime, jms:jme ),                                   &
           INTENT(IN   ) :: rain,lat
    REAL(kind_chem),  DIMENSION( ims:ime ,  jms:jme,num_chem ),                        &
           INTENT(INOUT   ) :: var_rmv
    REAL(kind_chem),  DIMENSION( its:ite ,  jts:jte ) :: var_sum
    REAL(kind_chem),  DIMENSION( its:ite ,  kts:kte, jts:jte ) :: var_rmvl
    REAL(kind_chem),  DIMENSION( its:ite ,  jts:jte ) :: frc,var_sum_clw,rain_clw
    real(kind_chem) :: dvar,factor,rho_water,ff
    real(kind_chem), dimension(num_chem):: alpha
    integer :: nv,i,j,k


    alpha = 0.


        select case (chem_opt)
          case (CHEM_OPT_GOCART)
            alpha = 1.0
            alpha(p_so2   ) = 0.3
            alpha(p_msa   ) = 0.3
            alpha(p_dms   ) = 0.3
            alpha(p_sulf) = 0.6
            alpha(p_bc1) = 0.3
            alpha(p_bc2) = 0.6
            alpha(p_oc1) = 0.1
            alpha(p_oc2) = 0.2
            alpha(p_dust_1) = 0.2
            alpha(p_dust_2) = 0.2
            alpha(p_dust_3) = 0.2
            alpha(p_dust_4) = 0.2
            alpha(p_dust_5) = 0.2

          case (CHEM_OPT_GOCART_RACM)
            alpha = 1.0
!            alpha(p_h2o2) = 0.5
          case (CHEM_OPT_RACM_SOA_VBS)
!            alpha(numgas + 1:) = 0.5
!            alpha(p_sulf) = 0.5
!            alpha(p_hno3) = 1.0
!            alpha(p_h2o2) = 0.5
!            alpha(p_naai) = 1.0
!            alpha(p_naaj) = 1.0
!            alpha(p_clai) = 1.0
!            alpha(p_claj) = 1.0
!            alpha(p_nh4aj) = 1.0
!            alpha(p_nh4ai) = 1.0
!            alpha(p_no3aj) = 1.0
!            alpha(p_no3ai) = 1.0
!            alpha(p_so4ai) = 1.0
!            alpha(p_so4aj) = 1.0
!            alpha(p_seas)  = 1.0
          case default
        end select





    rho_water = 1000.
    var_rmv (:,:,:)=0.
    do nv=1,num_chem
!
!

!
! proportionality constant
!
    !frc(:,:)=0.1
    !frc(:,:)=0.01 !lzhang
    ff=1.0
    if (nv>=p_seas_1 .and. nv<=p_seas_5) ff=2.0*10.
    do i=its,ite
    do j=jts,jte
     var_sum_clw(i,j)=0.
     var_sum(i,j)=0.
     var_rmvl(i,:,j)=0.
     rain_clw(i,j)=0.
     frc(i,j)=0.
     if(rain(i,j).gt.1.e-30)then
! convert rain back to rate
!
        rain_clw(i,j)=rain(i,j)/dt
! total cloud water
!
        do k=1,kte
           !dvar=max(0.,(moist(i,k,j,p_qc)+moist(i,k,j,p_qi)))
           !dvar=max(0.,(moist(i,k,j,p_qc)+moist(i,k,j,p_qi))*rho(i,k,j)*vvel(i,k,j)*dz8w(i,k,j))
           dvar=max(0.,(moist(i,k,j,p_qc))*rho(i,k,j)*vvel(i,k,j)*dz8w(i,k,j))
           var_sum_clw(i,j)=var_sum_clw(i,j)+dvar
           var_sum(i,j)=var_sum(i,j)+var(i,k,j,nv)*rho(i,k,j) !lzhang
        enddo
           if(var_sum(i,j).gt.1.e-30 .and. var_sum_clw(i,j).gt.1.e-30 ) then
   !        assuming that frc is onstant, it is my conversion factor 
              frc(i,j)=rain_clw(i,j)/var_sum_clw(i,j)

              !frc(i,j)=max(1.e-6,min(frc(i,j),.005)*ff)
              frc(i,j)=max(1.e-6,min(frc(i,j),1.))
           endif
     endif
    enddo
    enddo
!
! get rid of it
!
    do i=its,ite
    do j=jts,jte
     if(rain(i,j).gt.1.e-30 .and. var_sum(i,j).gt.1.e-30 .and. var_sum_clw(i,j).gt.1.e-30 ) then
       do k=kts,kte
        if(var(i,k,j,nv).gt.1.e-30 .and. (moist(i,k,j,p_qc)+moist(i,k,j,p_qi)).gt.1.e-30)then
        factor = max(0.,frc(i,j)*rho(i,k,j)*dz8w(i,k,j)*vvel(i,k,j))
        dvar=max(0.,alpha(nv)*factor/(1+factor)*var(i,k,j,nv))
        dvar=min(dvar,var(i,k,j,nv))
        var_rmvl(i,k,j)=dvar
        if((var(i,k,j,nv)-dvar).lt.1.e-16)then
           dvar=var(i,k,j,nv)-1.e-16
           var_rmvl(i,k,j)=dvar !lzhang
           var(i,k,j,nv)=var(i,k,j,nv)-dvar
        else
           var(i,k,j,nv)=var(i,k,j,nv)-dvar
        endif
        !var_rmv(i,j,nv)=var_rmv(i,j,nv)+var_rmvl(i,k,j)
        !!convert wetdeposition into ug/m2/s  
        var_rmv(i,j,nv)=var_rmv(i,j,nv)+(var_rmvl(i,k,j)*rho(i,k,j)*dz8w(i,k,j)/dt) !lzhang
        endif
       enddo
       var_rmv(i,j,nv)=max(0.,var_rmv(i,j,nv))
    endif
    enddo
    enddo
    enddo

  end subroutine wetdep_ls

!-------------------------------------------------------------------------
!     NASA/GSFC, Global Modeling and Assimilation Office, Code 900.3     !
!-------------------------------------------------------------------------
!BOP
!
! !IROUTINE: WetRemovalGOCART - Calculate aerosol wet removal due
!                               to large scale processes.
!
! !INTERFACE:
!

  subroutine WetRemovalGOCART ( i1, i2, j1, j2, k1, k2, n1, n2, cdt, &
                                num_chem, var_rmv, chem, ple, tmpu,  &
                                rhoa, dqcond, precc, precl,         &
                                ims, ime, jms, jme, kms, kme)
!                                ims, ime, jms, jme, kms, kme, rc )

! !USES:
   IMPLICIT NONE

! !INPUT PARAMETERS:
   integer, intent(in) :: i1, i2, j1, j2, k1, k2, n1, n2, num_chem, &
                          ims, ime, jms, jme, kms, kme
   real(kind_chem), intent(in)    :: cdt
   REAL(kind_chem),  DIMENSION( ims:ime , kms:kme , jms:jme ,1:num_chem),&
          INTENT(INOUT) :: chem
   REAL(kind_chem),  DIMENSION( ims:ime ,  jms:jme,num_chem ), &
          INTENT(INOUT   ) :: var_rmv !! tracer loss flux [kg m-2 s-1]
   real(kind_chem), dimension(ims:ime, kms:kme, jms:jme),&
          INTENT(IN)     :: ple, tmpu, rhoa, dqcond
   real(kind_chem), dimension(ims:ime ,  jms:jme) , &
          INTENT(IN)      :: precc, precl    ! cv, ls precip [mm day-1]

! !OUTPUT PARAMETERS:
!   integer, intent(out)             :: rc          ! Error return code:
                                                   !  0 - all is well
                                                   !  1 -

! !DESCRIPTION: Calculates the updated species concentration due to wet
!               removal.  As written, intended to function for large
!               scale (not convective) wet removal processes

!
! !REVISION HISTORY:
!
!  08Jan2010 - Colarco, based on GOCART implementation, does not
!                       include any size dependent term
!
!EOP
!-------------------------------------------------------------------------

! !Local Variables
   character(len=*), parameter :: myname = 'WetRemovalGOCART'
   integer  ::  i, j, k, n, nbins, LH, kk, ios,nv
   real(kind_chem) :: pdog(i1:i2,k1:k2,j1:j2)      ! air mass factor dp/g [kg m-2]
   real(kind_chem) :: pls, pcv, pac             ! ls, cv, tot precip [mm day-1]
   real(kind_chem) :: qls(k1:k2), qcv(k1:k2)          ! ls, cv portion dqcond [kg m-3 s-1]
   real(kind_chem) :: qmx, qd, A                ! temporary variables on moisture
   real(kind_chem) :: F, B, BT                  ! temporary variables on cloud, freq.
   real(kind_chem), allocatable :: fd(:,:)      ! flux across layers [kg m-2]
   real(kind_chem), allocatable :: DC(:)        ! scavenge change in mass mixing ratio
!  Rain parameters from Liu et al.
   real(kind_chem), parameter :: B0_ls = 1.0e-4
   real(kind_chem), parameter :: F0_ls = 1.0
   real(kind_chem), parameter :: XL_ls = 5.0e-4
   real(kind_chem), parameter :: B0_cv = 1.5e-3
   real(kind_chem), parameter :: F0_cv = 0.3
   real(kind_chem), parameter :: XL_cv = 2.0e-3
!  Duration of rain: ls = model timestep, cv = 1800 s (<= cdt)
   real(kind_chem)            :: Td_ls
   real(kind_chem)            :: Td_cv
   real(kind_chem), dimension(num_chem):: alpha

!  Efficiency of dust wet removal (since dust is really not too hygroscopic)
!  Applied only to in-cloud scavenging
   real(kind_chem) :: effRemoval
!  real(kind_chem),dimension(20) ::fwet
!  tracer: p_so2=1 p_sulf=2 p_dms=3 p_msa=4 p_p25=5 p_bc1=6 p_bc2=7 p_oc1=8
!  p_oc2=9 p_dust_1=10 p_dust_2=11 p_dust_3=12 p_dust_4=13 p_dust_5=14
!  p_seas_1=15 p_seas_2=16 p_seas_3=17 p_seas_4=18 p_seas_5=19 p_p10  =20
!   data fwet /0.,1.5,0.,0.,1.,0.7,0.7,0.4,0.4,1.,1.,1.,1.,1.,1.,1.,1.,1.,1.,1./
!  rc=0.

!  Initialize local variables
!  --------------------------
!   rc = CHEM_RC_SUCCESS

        select case (chem_opt)
          case (CHEM_OPT_GOCART)
            alpha(p_so2   ) = 0.
            alpha(p_sulf  ) = 1.5
            alpha(p_dms   ) = 0.
            alpha(p_msa   ) = 0.
            alpha(p_p25   ) = 1.
            alpha(p_bc1   ) = 0.7
            alpha(p_bc2   ) = 0.7
            alpha(p_oc1   ) = 1.
            alpha(p_oc2   ) = 1.
            alpha(p_dust_1) = 1.
            alpha(p_dust_2) = 1.
            alpha(p_dust_3) = 1.
            alpha(p_dust_4) = 1.
            alpha(p_dust_5) = 1.
            alpha(p_seas_1) = 1.
            alpha(p_seas_2) = 1.
            alpha(p_seas_3) = 1.
            alpha(p_seas_4) = 1.
            alpha(p_seas_5) = 1.
            alpha(p_p10   ) = 1.
          case default
            ! -- NGAC large scale wet deposition only works with GOCART
        end select

   Td_ls = cdt
   Td_cv = cdt
   nbins = n2-n1+1
   var_rmv = 0.0

!  Allocate the dynamic arrays
   allocate(fd(k1:k2,nbins),stat=ios)
!   if (chem_rc_test((ios .ne. 0), msg="Failed to allocate memory", &
!     file=__FILE__, line=__LINE__, rc=rc)) return
   allocate(dc(nbins),stat=ios)
!   if (chem_rc_test((ios .ne. 0), msg="Failed to allocate memory", &
!     file=__FILE__, line=__LINE__, rc=rc)) return

!  Accumulate the 3-dimensional arrays of rhoa and pdog
   do j = j1, j2
    do i = i1, i2
     !pdog(i,k1:k2,j) = (ple(i,k1+1:k2+1,j)-ple(i,k1:k2,j)) / grav
      pdog(i,k1:k2,j) = (ple(i,k1:k2,j)-ple(i,k1+1:k2+1,j)) / grav !lzhang
    enddo
   enddo

   do nv=1, num_chem
!  Loop over spatial indices
   do j = j1, j2
    do i = i1, i2

!    Check for total precipitation amount
!    Assume no precip in column if precl+precc = 0
     pac = precl(i,j) + precc(i,j)
     if(pac .le. 0.) goto 100
     pls = precl(i,j)
     pcv = precc(i,j)

!    Initialize the precipitation fields
     qls(:)  = 0.
     qcv(:)  = 0.
     fd(:,:) = 0.

!    Find the highest model layer experiencing rainout.  Assumes no
!    scavenging if T < 258 K
     !LH = 0
     LH = k2+1 !lzhang
     !do k = k1, k2
     do k = k2, k1,-1 !lzhang
      if(dqcond(i,k,j) .lt. 0. .and. tmpu(i,k,j) .gt. 258.) then
       LH = k
       goto 15
      endif
     end do
 15  continue
     !if(LH .lt. 1) goto 100
     if(LH .gt. k2) goto 100 !lzhang

!    convert dqcond from kg water/kg air/s to kg water/m3/s and reverse
!    sign so that dqcond < 0. (positive precip) means qls and qcv > 0.
     !do k = LH, k2
     do k = LH, k1, -1  !lzhang
      qls(k) = -dqcond(i,k,j)*pls/pac*rhoa(i,k,j)
      qcv(k) = -dqcond(i,k,j)*pcv/pac*rhoa(i,k,j)
     end do

!    Loop over vertical to do the scavenging!
     !do k = LH, k2
     do k = LH, k1, -1  !lzhang

!-----------------------------------------------------------------------------
!   (1) LARGE-SCALE RAINOUT:
!       Tracer loss by rainout = TC0 * F * exp(-B*dt)
!         where B = precipitation frequency,
!               F = fraction of grid box covered by precipitating clouds.
!       We assume that tracer scavenged by rain is falling down to the
!       next level, where a fraction could be re-evaporated to gas phase
!       if Qls is less then 0 in that level.
!-----------------------------------------------------------------------------
      if (qls(k) .gt. 0.) then
       F  = F0_ls / (1. + F0_ls*B0_ls*XL_ls/(qls(k)*cdt/Td_ls))
       B  = B0_ls/F0_ls +1./(F0_ls*XL_ls/qls(k))
       BT = B * Td_ls
       if (BT.gt.10.) BT = 10.               !< Avoid overflow >
!      Adjust du level:
       do n = 1, nbins
        effRemoval = alpha(nv)
        DC(n) = chem(i,k,j,nv) * F * effRemoval *(1.-exp(-BT))
        if (DC(n).lt.0.) DC(n) = 0.
        chem(i,k,j,nv) = chem(i,k,j,nv)-DC(n)
        if (chem(i,k,j,nv) .lt. 1.0E-32) chem(i,k,j,nv) = 1.0E-32
       end do
!      Flux down:  unit is kg m-2
!      Formulated in terms of production in the layer.  In the revaporation step
!      we consider possibly adding flux from above...
       do n = 1, nbins
        Fd(k,n) = DC(n)*pdog(i,k,j)
       end do

      end if                                    ! if Qls > 0  >>>

!-----------------------------------------------------------------------------
! * (2) LARGE-SCALE WASHOUT:
! *     Occurs when rain at this level is less than above.
!-----------------------------------------------------------------------------
      !if(k .gt. LH .and. qls(k) .ge. 0.) then
      if(k .lt. LH .and. qls(k) .ge. 0.) then !lzhang
       !if(qls(k) .lt. qls(k-1)) then
       if(qls(k) .lt. qls(k+1)) then  !lzhang
!       Find a maximum F overhead until the level where Qls<0.
        Qmx   = 0.
        !do kk = k-1,LH,-1
        do kk = k+1,LH  !lzhang
         if (Qls(kk).gt.0.) then
          Qmx = max(Qmx,Qls(kk))
         else
          goto 333
         end if
        end do

 333    continue
        F = F0_ls / (1. + F0_ls*B0_ls*XL_ls/(Qmx*cdt/Td_ls))
        if (F.lt.0.01) F = 0.01
!-----------------------------------------------------------------------------
!  The following is to convert Q(k) from kgH2O/m3/sec to mm/sec in order
!  to use the Harvard formula.  Convert back to mixing ratio by multiplying
!  by rhoa.  Multiply by pdog gives kg/m2/s of precip.  Divide by density
!  of water (=1000 kg/m3) gives m/s of precip and multiply by 1000 gives
!  units of mm/s (omit the multiply and divide by 1000).
!-----------------------------------------------------------------------------

        Qd = Qmx /rhoa(i,k,j)*pdog(i,k,j)
        if (Qd.ge.50.) then
         B = 0.
        else
         B = Qd * 0.1
        end if
        BT = B * cdt
        if (BT.gt.10.) BT = 10.

!       Adjust du level:
        do n = 1, nbins
         DC(n) = chem(i,k,j,nv) * F * (1.-exp(-BT))
         if (DC(n).lt.0.) DC(n) = 0.
         chem(i,k,j,nv) = chem(i,k,j,nv)-DC(n)
         if (chem(i,k,j,nv) .lt. 1.0E-32) &
          chem(i,k,j,nv) = 1.0E-32
          var_rmv(i,j,nv) = var_rmv(i,j,nv)+DC(n)*pdog(i,k,j)/cdt !ug/m2/s
        end do

       end if
      end if                                    ! if ls washout  >>>
#if 0
!-----------------------------------------------------------------------------
!  (3) CONVECTIVE RAINOUT:
!      Tracer loss by rainout = dd0 * F * exp(-B*dt)
!        where B = precipitation frequency,
!              F = fraction of grid box covered by precipitating clouds.
!-----------------------------------------------------------------------------

      if (qcv(k) .gt. 0.) then
       F  = F0_cv / (1. + F0_cv*B0_cv*XL_cv/(Qcv(k)*cdt/Td_cv))
       B  = B0_cv
       BT = B * Td_cv
       if (BT.gt.10.) BT = 10.               !< Avoid overflow >

!      Adjust du level:
       do n = 1, nbins
        effRemoval = alpha(nv)
        DC(n) = chem(i,k,j,nv) * F * effRemoval * (1.-exp(-BT))
        if (DC(n).lt.0.) DC(n) = 0.
        chem(i,k,j,nv) = chem(i,k,j,nv)-DC(n)
        if (chem(i,k,j,nv) .lt. 1.0E-32) chem(i,k,j,nv) = 1.0E-32
       end do

!------  Flux down:  unit is kg. Including both ls and cv.
       do n = 1, nbins
        Fd(k,n) = Fd(k,n) + DC(n)*pdog(i,k,j)
       end do

      end if                                  ! if Qcv > 0   >>>

!-----------------------------------------------------------------------------
!  (4) CONVECTIVE WASHOUT:
!      Occurs when rain at this level is less than above.
!-----------------------------------------------------------------------------

      !if (k.gt.LH .and. Qcv(k).ge.0.) then
      if (k.lt.LH .and. Qcv(k).ge.0.) then !lzhang
       !if (Qcv(k).lt.Qcv(k-1)) then
       if (Qcv(k).lt.Qcv(k+1)) then !lzhang
!-----  Find a maximum F overhead until the level where Qls<0.
        Qmx   = 0.
        !do kk = k-1, LH, -1
        do kk = k+1, LH !lzhang
         if (Qcv(kk).gt.0.) then
          Qmx = max(Qmx,Qcv(kk))
         else
          goto 444
         end if
        end do

 444    continue
        F = F0_cv / (1. + F0_cv*B0_cv*XL_cv/(Qmx*cdt/Td_cv))
        if (F.lt.0.01) F = 0.01
!-----------------------------------------------------------------------------
!  The following is to convert Q(k) from kgH2O/m3/sec to mm/sec in order
!  to use the Harvard formula.  Convert back to mixing ratio by multiplying
!  by rhoa.  Multiply by pdog gives kg/m2/s of precip.  Divide by density
!  of water (=1000 kg/m3) gives m/s of precip and multiply by 1000 gives
!  units of mm/s (omit the multiply and divide by 1000).
!-----------------------------------------------------------------------------

        Qd = Qmx / rhoa(i,k,j)*pdog(i,k,j)
        if (Qd.ge.50.) then
         B = 0.
        else
         B = Qd * 0.1
        end if
        BT = B * cdt
        if (BT.gt.10.) BT = 10.

!       Adjust du level:
        do n = 1, nbins
         DC(n) = chem(i,k,j,nv) * F * (1.-exp(-BT))
         if (DC(n).lt.0.) DC(n) = 0.
         chem(i,k,j,nv) = chem(i,k,j,nv)-DC(n)
         if (chem(i,k,j,nv) .lt. 1.0E-32) &
          chem(i,k,j,nv) = 1.0E-32
          var_rmv(i,j,nv) = var_rmv(i,j,nv)+DC(n)*pdog(i,k,j)/cdt !ug/m2/s
        end do

       end if
      end if                                    ! if cv washout  >>>
#endif
!-----------------------------------------------------------------------------
!  (5) RE-EVAPORATION.  Assume that SO2 is re-evaporated as SO4 since it
!      has been oxidized by H2O2 at the level above.
!-----------------------------------------------------------------------------
!     Add in the flux from above, which will be subtracted if reevaporation occurs
      !if(k .gt. LH) then
      if(k .lt. LH) then !lzhang
       do n = 1, nbins
        !Fd(k,n) = Fd(k,n) + Fd(k-1,n)
        Fd(k,n) = Fd(k,n) + Fd(k+1,n)  !lzhang
       end do

!      Is there evaporation in the currect layer?
       if (-dqcond(i,k,j) .lt. 0.) then
!       Fraction evaporated = H2O(k)evap / H2O(next condensation level).
        !if (-dqcond(i,k-1,j) .gt. 0.) then
        if (-dqcond(i,k+1,j) .gt. 0.) then !lzhang

          A =  abs(  dqcond(i,k,j) * pdog(i,k,j)    &
            !/      ( dqcond(i,k-1,j) * pdog(i,k-1,j))  )
            /      ( dqcond(i,k+1,j) * pdog(i,k+1,j))  ) !lzhang
          if (A .gt. 1.) A = 1.

!         Adjust tracer in the level
          do n = 1, nbins
           !DC(n) =  Fd(k-1,n) / pdog(i,k,j) * A
           DC(n) =  Fd(k+1,n) / pdog(i,k,j) * A  !lzhang
           chem(i,k,j,nv) = chem(i,k,j,nv) + DC(n)
           chem(i,k,j,nv) = max(chem(i,k,j,nv),1.e-32)
!          Adjust the flux out of the bottom of the layer
           Fd(k,n)  = Fd(k,n) - DC(n)*pdog(i,k,j)
          end do

        endif
       endif                                   ! if -moistq < 0
      endif
     end do  ! k

     do n = 1, nbins
       !var_rmv(i,j,nv) = var_rmv(i,j,nv)+Fd(k2,n)/cdt !lzhang
       var_rmv(i,j,nv) = var_rmv(i,j,nv)+Fd(k1,n)/cdt ! ug/m2/s
     end do

 100 continue
    end do   ! i
   end do    ! j
   end do    !nv for num_chem

   deallocate(fd,DC,stat=ios)
!   if (chem_rc_test((ios .ne. 0), msg="Failed to deallocate memory", &
!     file=__FILE__, line=__LINE__, rc=rc)) return

   end subroutine WetRemovalGOCART

end module dep_wet_ls_mod
