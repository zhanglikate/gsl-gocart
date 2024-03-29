!>\file gsd_chem_dust_wrapper.F90
!! This file is GSDChem dsut wrapper with CCPP coupling to FV3
!! Haiqin.Li@noaa.gov 05/2020
!! Kate.Zhang@noaa.gov 04/2023

 module gsd_chem_dust_wrapper

   use physcons,        only : g => con_g, pi => con_pi
   use machine ,        only : kind_phys
   use gsd_chem_config
   use dust_gocart_mod, only : gocart_dust_driver
   use dust_afwa_mod,   only : gocart_dust_afwa_driver
   use dust_fengsha_mod,only : gocart_dust_fengsha_driver
   use dust_data_mod

   implicit none

   private

   public :: gsd_chem_dust_wrapper_init, gsd_chem_dust_wrapper_run, gsd_chem_dust_wrapper_finalize

contains

!> \brief Brief description of the subroutine
!!
      subroutine gsd_chem_dust_wrapper_init()
      end subroutine gsd_chem_dust_wrapper_init

!> \brief Brief description of the subroutine
!!
!! \section arg_table_gsd_chem_dust_wrapper_finalize Argument Table
!!
      subroutine gsd_chem_dust_wrapper_finalize()
      end subroutine gsd_chem_dust_wrapper_finalize

!> \defgroup gsd_chem_dust_group GSD Chem seas wrapper Module
!! This is the gsd chemistry
!>\defgroup gsd_chem_dust_wrapper GSD Chem seas wrapper Module  
!> \ingroup gsd_chem_dust_group
!! This is the GSD Chem seas wrapper Module
!! \section arg_table_gsd_chem_dust_wrapper_run Argument Table
!! \htmlinclude gsd_chem_dust_wrapper_run.html
!!
!>\section gsd_chem_dust_wrapper GSD Chemistry Scheme General Algorithm
!> @{
    subroutine gsd_chem_dust_wrapper_run(im, kte, kme, ktau, dt, garea, land,   &
                   jdate,lakefrac, sncovr,                                      &                                               
                   u10m, v10m, ustar, rlat, rlon, tskin, hf2d, pb2d,            &
                   pr3d, ph3d,phl3d, prl3d, tk3d, us3d, vs3d, spechum,          &
                   nsoil, smc, vegtype, soiltyp, sigmaf, dswsfc, zorl,snow_cplchm, &
                   dust_in,emi_in, nseasalt,ntrac,                              &
                   ntdust1,ntdust2,ntdust3,ntdust4,ntdust5,ndust,               &
                   gq0,qgrs,duem,                                               &
                   chem_opt_in,dust_opt_in,dust_calcdrag_in,                    &
                   dust_alpha_in,dust_gamma_in,pert_scale_dust,                 &
                   emis_amp_dust, do_sppt_emis, sppt_wts, errmsg,errflg)

    implicit none


    integer,        intent(in) :: im,kte,kme,ktau,nsoil
    integer,        intent(in) :: nseasalt,ntrac,jdate(8)
    integer,        intent(in) :: ntdust1,ntdust2,ntdust3,ntdust4,ntdust5,ndust
    real(kind_phys),intent(in) :: dt, emis_amp_dust, pert_scale_dust

    logical,        intent(in) :: do_sppt_emis
    real(kind_phys), optional, intent(in) :: sppt_wts(:,:)

    integer, parameter :: ids=1,jds=1,jde=1, kds=1
    integer, parameter :: ims=1,jms=1,jme=1, kms=1
    integer, parameter :: its=1,jts=1,jte=1, kts=1

    integer, dimension(im), intent(in) :: land, vegtype, soiltyp        
    real(kind_phys), dimension(im,nsoil), intent(in) :: smc
    real(kind_phys), dimension(im, 12, 5), intent(in) :: dust_in
    real(kind_phys), dimension(im,   10), intent(in) :: emi_in
    real(kind_phys), dimension(im), intent(in) :: u10m, v10m, ustar,              &
                lakefrac, sncovr, garea, rlat,rlon, tskin,                      &
                hf2d, pb2d, sigmaf, dswsfc, zorl, snow_cplchm 
    real(kind_phys), dimension(im,kme), intent(in) :: ph3d, pr3d
    real(kind_phys), dimension(im,kte), intent(in) :: phl3d, prl3d, tk3d,        &
                us3d, vs3d, spechum
    real(kind_phys), dimension(im,kte,ntrac), intent(inout) :: gq0, qgrs
    real(kind_phys), dimension(im,ndust    ), intent(inout) :: duem
    integer,        intent(in) :: chem_opt_in, dust_opt_in, dust_calcdrag_in
    real(kind_phys),intent(in) :: dust_alpha_in,dust_gamma_in
    character(len=*), intent(out) :: errmsg
    integer,          intent(out) :: errflg

    real(kind_phys), dimension(ims:im, kms:kme,jms:jme) :: rri, t_phy, u_phy, v_phy,       &
                     p_phy, z_at_w, dz8w, p8w, t8w, rho_phy

    real(kind_phys), dimension(ims:im, jms:jme) :: u10, v10, ust, tsk,            &
                     xland, xlat, xlong,flake,fsnow, dxy, rcav, rnav, hfx, pbl

!>- vapor & chemistry variables
    real(kind_phys), dimension(ims:im, kms:kme, jms:jme, 1:num_moist)  :: moist 
    real(kind_phys), dimension(ims:im, kms:kme, jms:jme, 1:num_chem )  :: chem

    integer :: ide, ime, ite, kde

!>- dust & chemistry variables
    real(kind_phys), dimension(ims:im, jms:jme, 1:3) ::    erod ! read from input
    real(kind_phys), dimension(ims:im, jms:jme) :: ssm, rdrag, uthr, snowh  ! fengsha dust
    real(kind_phys), dimension(ims:im, jms:jme) :: vegfrac, rmol, gsw, znt, clayf, sandf
    real(kind_phys), dimension(ims:im, 1:nsoil, jms:jme) :: smois
    real(kind_phys), dimension(ims:im, 1:1, jms:jme, 1:num_emis_dust) :: emis_dust
    real(kind_phys), dimension(ims:im, 1:1, jms:jme, 1:5)             :: srce_dust
    real(kind_phys), dimension(ims:im, jms:jme) :: dusthelp
    integer,         dimension(ims:im, jms:jme) :: isltyp, ivgtyp

    integer :: current_month
    real(kind_phys) :: dtstep
    real(kind_phys), parameter :: ugkg = 1.e-09_kind_phys !lzhang
    real(kind_phys), dimension(1:num_chem) :: ppm2ugkg

!>-- local variables
    real(kind_phys) :: curr_secs
    real(kind_phys) :: factor, factor2, factor3
    logical :: store_arrays
    integer :: nbegin, nv, nvv
    integer :: i, j, jp, k, kp, n
    real(kind_phys), dimension(ims:im,jms:jme) :: random_factor
  

    errmsg = ''
    errflg = 0

    chem_opt          = chem_opt_in
    dust_opt          = dust_opt_in
    dust_calcdrag     = dust_calcdrag_in
    chem = 0.

    ! -- initialize dust emissions
    emis_dust = 0._kind_phys
    current_month=jdate(2)      ! needed for the dust input data

    ! -- set domain
    ide=im 
    ime=im
    ite=im
    kde=kte

    if(do_sppt_emis) then
      random_factor(:,jms) = pert_scale_dust*max(min(1+(sppt_wts(:,kme/2)-1)*emis_amp_dust,2.0),0.0)
    else
      random_factor = 1.0
    endif

    ! -- volume to mass fraction conversion table (ppm -> ug/kg)
    ppm2ugkg         = 1._kind_phys
   !ppm2ugkg(p_so2 ) = 1.e+03_kind_phys * mw_so2_aer / mwdry
    ppm2ugkg(p_sulf) = 1.e+03_kind_phys * mw_so4_aer / mwdry

    ! -- compute accumulated large-scale and convective rainfall since last call
    if (ktau > 1) then
      dtstep = call_chemistry * dt
    else
      dtstep = dt
    end if

!>- get ready for chemistry run
    call gsd_chem_prep_dust(                                             &
        ktau,dtstep,current_month,                                       &
        u10m,v10m,ustar,land,lakefrac,sncovr,garea,rlat,rlon,tskin,      &
        pr3d,ph3d,phl3d,tk3d,prl3d,us3d,vs3d,spechum,                    &
        nsoil,smc,vegtype,soiltyp,sigmaf,dswsfc,zorl,                    &
        snow_cplchm,dust_in,emi_in,                                      &
        hf2d,pb2d,u10,v10,ust,tsk,xland,xlat,xlong,flake,fsnow,dxy,      &
        rri,t_phy,u_phy,v_phy,p_phy,rho_phy,dz8w,p8w,t8w,z_at_w,         &
        ntdust1,ntdust2,ntdust3,ntdust4,ntdust5,                         &
        ntrac,gq0,num_chem, num_moist,ppm2ugkg,moist,chem,               &
        smois,ivgtyp,isltyp,vegfrac,rmol,gsw,znt,hfx,pbl,                &
        snowh,clayf,rdrag,sandf,ssm,uthr,erod,                           &
        ids,ide, jds,jde, kds,kde,                                       &
        ims,ime, jms,jme, kms,kme,                                       &
        its,ite, jts,jte, kts,kte)


    !-- compute dust
    !store_arrays = .false.
    select case (dust_opt)
      case (DUST_OPT_AFWA)
        dust_alpha = dust_alpha_in 
        dust_gamma = dust_gamma_in
        call gocart_dust_afwa_driver(ktau,dt,                           &
          chem,rho_phy,smois,p8w,erod,isltyp,                           &
          xland,xlat,xlong,dxy,g,emis_dust,srce_dust,                   &
          ust,znt,clayf,sandf,                                          &
          num_emis_dust,num_chem,nsoil,                                 &
          ids,ide, jds,jde, kds,kde,                                    &
          ims,ime, jms,jme, kms,kme,                                    &
          its,ite, jts,jte, kts,kte)
       !store_arrays = .true.
      case (DUST_OPT_FENGSHA)
       dust_alpha    = dust_alpha_in  !fengsha_alpha
       dust_gamma    = dust_gamma_in  !fengsha_gamma
       call gocart_dust_fengsha_driver(dt,chem,rho_phy,smois,p8w,ssm,   &
            isltyp,vegfrac,snowh,xland,flake,fsnow,dxy,g,emis_dust,     &
            ust,znt,clayf,sandf,rdrag,uthr,                             &
            num_emis_dust,num_chem,nsoil,                               &
            random_factor,                                              &
            ids,ide, jds,jde, kds,kde,                                  &
            ims,ime, jms,jme, kms,kme,                                  &
            its,ite, jts,jte, kts,kte)
       !store_arrays = .true.
      case (DUST_OPT_GOCART)
        dust_alpha = gocart_alpha
        dust_gamma = gocart_gamma
        call gocart_dust_driver(chem_opt,ktau,dt,rri,t_phy,moist,u_phy, &
          v_phy,chem,rho_phy,dz8w,smois,u10,v10,p8w,erod,ivgtyp,isltyp, &
          vegfrac,xland,xlat,xlong,gsw,dxy,g,emis_dust,srce_dust,       &
          dusthelp,num_emis_dust,num_moist,num_chem,nsoil,              &
          current_month,                                                &
          ids,ide, jds,jde, kds,kde,                                    &
          ims,ime, jms,jme, kms,kme,                                    &
          its,ite, jts,jte, kts,kte)
      case default
        errmsg = 'Logic error in gsd_chem_dust_wrapper_run: invalid dust_opt'
        errflg = 1
        return
       !store_arrays = .true.
    end select



    ! -- put chem stuff back into tracer array
    do k=kts,kte
     do i=its,ite
       gq0(i,k,ntdust1  )=ppm2ugkg(p_dust_1) * max(epsilc,chem(i,k,1,p_dust_1))
       gq0(i,k,ntdust2  )=ppm2ugkg(p_dust_2) * max(epsilc,chem(i,k,1,p_dust_2))
       gq0(i,k,ntdust3  )=ppm2ugkg(p_dust_3) * max(epsilc,chem(i,k,1,p_dust_3))
       gq0(i,k,ntdust4  )=ppm2ugkg(p_dust_4) * max(epsilc,chem(i,k,1,p_dust_4))
       gq0(i,k,ntdust5  )=ppm2ugkg(p_dust_5) * max(epsilc,chem(i,k,1,p_dust_5))
     enddo
    enddo

    do k=kts,kte
     do i=its,ite
       qgrs(i,k,ntdust1 )=gq0(i,k,ntdust1  )
       qgrs(i,k,ntdust2 )=gq0(i,k,ntdust2  )
       qgrs(i,k,ntdust3 )=gq0(i,k,ntdust3  )
       qgrs(i,k,ntdust4 )=gq0(i,k,ntdust4  )
       qgrs(i,k,ntdust5 )=gq0(i,k,ntdust5  )
     enddo
    enddo

    duem(:,:)=ugkg*emis_dust(:,1,1,:)
!
   end subroutine gsd_chem_dust_wrapper_run
!> @}

   subroutine gsd_chem_prep_dust(                                      &
        ktau,dtstep,current_month,                                     &
        u10m,v10m,ustar,land,lakefrac,sncovr,garea,rlat,rlon,ts2d,     &
        pr3d,ph3d,phl3d,tk3d,prl3d,us3d,vs3d,spechum,                  &
        nsoil,smc,vegtype,soiltyp,sigmaf,dswsfc,zorl,                  &
        snow_cplchm,dust_in,emi_in,hf2d,pb2d,                          &
        u10,v10,ust,tsk,xland,xlat,xlong,flake,fsnow,dxy,              &
        rri,t_phy,u_phy,v_phy,p_phy,rho_phy,dz8w,p8w,t8w,              &
        z_at_w, ntdust1,ntdust2,ntdust3,ntdust4,ntdust5,ntrac,gq0,     &
        num_chem, num_moist,ppm2ugkg,moist,chem,                       &
        smois,ivgtyp,isltyp,vegfrac,rmol,gsw,znt,hfx,pbl,              &
        snowh,clayf,rdrag,sandf,ssm,uthr,erod,                         &
        ids,ide, jds,jde, kds,kde,                                     &
        ims,ime, jms,jme, kms,kme,                                     &
        its,ite, jts,jte, kts,kte)

    !Chem input configuration
    integer, intent(in) :: ktau,current_month
    real(kind=kind_phys), intent(in) :: dtstep

    !FV3 input variables
    integer, intent(in) :: nsoil
    integer, dimension(ims:ime), intent(in) :: land, vegtype, soiltyp
    integer, intent(in) :: ntrac
    integer, intent(in) :: ntdust1,ntdust2,ntdust3,ntdust4,ntdust5
    real(kind=kind_phys), dimension(ims:ime), intent(in) ::                 & 
         u10m, v10m, ustar, lakefrac,sncovr,garea, rlat, rlon, ts2d, sigmaf, dswsfc,       &
         zorl, snow_cplchm, hf2d, pb2d
    real(kind=kind_phys), dimension(ims:ime, nsoil),   intent(in) :: smc 
    real(kind=kind_phys), dimension(ims:ime, 12,  5),   intent(in) :: dust_in
    real(kind=kind_phys), dimension(ims:ime,    10),   intent(in) :: emi_in
    real(kind=kind_phys), dimension(ims:ime, kms:kme), intent(in) ::     &
         pr3d,ph3d
    real(kind=kind_phys), dimension(ims:ime, kts:kte), intent(in) ::       &
         phl3d,tk3d,prl3d,us3d,vs3d,spechum
    real(kind=kind_phys), dimension(ims:ime, kts:kte,ntrac), intent(in) :: gq0


    !GSD Chem variables
    integer,intent(in) ::  num_chem,num_moist
    integer,intent(in) ::  ids,ide, jds,jde, kds,kde,                      &
                           ims,ime, jms,jme, kms,kme,                      &
                           its,ite, jts,jte, kts,kte

    real(kind_phys), dimension(num_chem), intent(in) :: ppm2ugkg

    
    integer,dimension(ims:ime, jms:jme), intent(out) :: isltyp, ivgtyp
    real(kind_phys), dimension(ims:ime, jms:jme, 1:3), intent(inout) :: erod
    real(kind_phys), dimension(ims:ime, kms:kme, jms:jme), intent(out) ::              & 
         rri, t_phy, u_phy, v_phy, p_phy, rho_phy, dz8w, p8w, t8w
    real(kind_phys), dimension(ims:ime, jms:jme),          intent(out) ::              &
         u10, v10, ust, tsk, xland, xlat, xlong, dxy, vegfrac, rmol, gsw, znt, hfx,    &
         pbl, snowh, clayf, rdrag, sandf, ssm, uthr, flake, fsnow
    real(kind_phys), dimension(ims:ime, kms:kme, jms:jme, 1:num_moist), intent(out) :: moist
    real(kind_phys), dimension(ims:ime, kms:kme, jms:jme, 1:num_chem),  intent(out) :: chem

    real(kind_phys), dimension(ims:ime, kms:kme, jms:jme), intent(out) :: z_at_w
    real(kind_phys), dimension(ims:ime, 1:nsoil, jms:jme), intent(out) :: smois

    ! -- local variables
!   real(kind=kind_phys), dimension(ims:ime, kms:kme, jms:jme) :: p_phy
    real(kind_phys) ::  factor,factor2,pu,pl
    integer i,ip,j,jp,k,kp,kk,kkp,nv,l,ll,n


    ! -- initialize output arrays
    isltyp         = 0._kind_phys
    ivgtyp         = 0._kind_phys
    rri            = 0._kind_phys
    t_phy          = 0._kind_phys
    u_phy          = 0._kind_phys
    v_phy          = 0._kind_phys
    p_phy          = 0._kind_phys
    rho_phy        = 0._kind_phys
    dz8w           = 0._kind_phys
    p8w            = 0._kind_phys
    t8w            = 0._kind_phys
    u10            = 0._kind_phys
    v10            = 0._kind_phys
    ust            = 0._kind_phys
    tsk            = 0._kind_phys
    xland          = 0._kind_phys
    xlat           = 0._kind_phys
    xlong          = 0._kind_phys
    flake          = 0._kind_phys
    fsnow          = 0._kind_phys
    dxy            = 0._kind_phys
    vegfrac        = 0._kind_phys
    rmol           = 0._kind_phys
    gsw            = 0._kind_phys
    znt            = 0._kind_phys
    hfx            = 0._kind_phys
    pbl            = 0._kind_phys
    snowh          = 0._kind_phys
    clayf          = 0._kind_phys
    rdrag          = 0._kind_phys
    sandf          = 0._kind_phys 
    ssm            = 0._kind_phys
    uthr           = 0._kind_phys
    moist          = 0._kind_phys  
    chem           = 0._kind_phys
    z_at_w         = 0._kind_phys


    do i=its,ite
     u10  (i,1)=u10m (i)
     v10  (i,1)=v10m (i)
     tsk  (i,1)=ts2d (i)
     ust  (i,1)=ustar(i)
     flake(i,1)=lakefrac(i)
     fsnow(i,1)=sncovr(i)
     dxy  (i,1)=garea(i)
     xland(i,1)=real(land(i))
     xlat (i,1)=rlat(i)*180./pi
     xlong(i,1)=rlon(i)*180./pi
     gsw  (i,1)=dswsfc(i)
     znt  (i,1)=zorl(i)*0.01
     hfx  (i,1)=hf2d(i)
     pbl  (i,1)=pb2d(i)
     snowh(i,1)=snow_cplchm(i)*0.001
     clayf(i,1)=dust_in(i,current_month,1)
     rdrag(i,1)=dust_in(i,current_month,2)
     sandf(i,1)=dust_in(i,current_month,3)
     ssm  (i,1)=dust_in(i,current_month,4)
     uthr (i,1)=dust_in(i,current_month,5)
     ivgtyp (i,1)=vegtype(i)
     isltyp (i,1)=soiltyp(i)
     vegfrac(i,1)=sigmaf (i)
     erod (i,1,1)=emi_in(i,8) ! --ero1
     erod (i,1,2)=emi_in(i,9) ! --ero2
     erod (i,1,3)=emi_in(i,10)! --ero3
    enddo
   
    rmol=0.

    do k=1,nsoil
     do j=jts,jte
      do i=its,ite
       smois(i,k,j)=smc(i,k)
      enddo
     enddo
    enddo

    do j=jts,jte
      jp = j - jts + 1
      do i=its,ite
         ip = i - its + 1
         z_at_w(i,kts,j)=max(0.,ph3d(ip,1)/g)
      enddo
    enddo

    do j=jts,jte
      jp = j - jts + 1
      do k=kts,kte
        kp = k - kts + 1
        do i=its,ite
          ip = i - its + 1
          dz8w(i,k,j)=abs(ph3d(ip,kp+1)-ph3d(ip,kp))/g
          z_at_w(i,k+1,j)=z_at_w(i,k,j)+dz8w(i,k,j)
        enddo
      enddo
    enddo

    do j=jts,jte
      jp = j - jts + 1
      do k=kts,kte+1
        kp = k - kts + 1
        do i=its,ite
          ip = i - its + 1
          p8w(i,k,j)=pr3d(ip,kp)
        enddo
      enddo
    enddo

    do j=jts,jte
      jp = j - jts + 1
      do k=kts,kte+1
        kk=min(k,kte)
        kkp = kk - kts + 1
        do i=its,ite
          ip = i - its + 1
          dz8w(i,k,j)=z_at_w(i,kk+1,j)-z_at_w(i,kk,j)
          t_phy(i,k,j)=tk3d(ip,kkp)
          p_phy(i,k,j)=prl3d(ip,kkp)
          u_phy(i,k,j)=us3d(ip,kkp)
          v_phy(i,k,j)=vs3d(ip,kkp)
          rho_phy(i,k,j)=p_phy(i,k,j)/(287.04*t_phy(i,k,j)*(1.+.608*spechum(ip,kkp)))
          rri(i,k,j)=1./rho_phy(i,k,j)
          moist(i,k,j,:)=0.
          moist(i,k,j,1)=gq0(ip,kkp,p_atm_shum)
          if (t_phy(i,k,j) > 265.) then
            moist(i,k,j,2)=gq0(ip,kkp,p_atm_cldq)
            moist(i,k,j,3)=0.
            if (moist(i,k,j,2) < 1.e-8) moist(i,k,j,2)=0.
          else
            moist(i,k,j,2)=0.
            moist(i,k,j,3)=gq0(ip,kkp,p_atm_cldq)
            if(moist(i,k,j,3) < 1.e-8)moist(i,k,j,3)=0.
          endif
          !--
        enddo
      enddo
    enddo

    do j=jts,jte
      do k=2,kte
        do i=its,ite
          t8w(i,k,j)=.5*(t_phy(i,k,j)+t_phy(i,k-1,j))
        enddo
      enddo
    enddo

    ! -- only used in phtolysis....
    do j=jts,jte
      do i=its,ite
        t8w(i,1,j)=t_phy(i,1,j)
        t8w(i,kte+1,j)=t_phy(i,kte,j)
      enddo
    enddo


 
    do k=kms,kte
     do i=ims,ime
       chem(i,k,jts,p_dust_1)=max(epsilc,gq0(i,k,ntdust1)/ppm2ugkg(p_dust_1))
       chem(i,k,jts,p_dust_2)=max(epsilc,gq0(i,k,ntdust2)/ppm2ugkg(p_dust_2))
       chem(i,k,jts,p_dust_3)=max(epsilc,gq0(i,k,ntdust3)/ppm2ugkg(p_dust_3))
       chem(i,k,jts,p_dust_4)=max(epsilc,gq0(i,k,ntdust4)/ppm2ugkg(p_dust_4))
       chem(i,k,jts,p_dust_5)=max(epsilc,gq0(i,k,ntdust5)/ppm2ugkg(p_dust_5))
     enddo
    enddo


    ! -- real-time application, keeping eruption constant

  end subroutine gsd_chem_prep_dust


!> @}
  end module gsd_chem_dust_wrapper
