Name:           perl-GRNOC-WebService
Version:        1.2.12
Release:        1%{?dist}
Summary:        GRNOC WebService Library for perl
License:        CHECK(Distributable)
Group:          Development/Libraries
URL:            http://search.cpan.org/dist/GRNOC-WebService/
Source0:        GRNOC-WebService-%{version}.tar.gz
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:      noarch
BuildRequires:  mod_perl
BuildRequires:  mod_perl-devel
BuildRequires:  httpd-devel
BuildRequires:  perl-HTML-Parser
BuildRequires:  perl-GRNOC-WebService-Client >= 1.3.1-2
BuildRequires:  perl-TimeDate
Requires:       perl-GRNOC-WebService-Client >= 1.3.1-2
Requires:       perl >= 5.8.8
Requires:       perl-JSON >= 2.17
Requires:       perl-JSON-XS >= 2.3
Requires:       perl-GRNOC-Config >= 1.0.7
Requires:       perl-URI
Requires:       perl-Clone
Requires:       perl-libwww-perl >= 5.833

%description
The WebService collection is a set of perl modules which are used to
provide and interact with GRNOC web services using Cosign Authentication
and CGI/* formats.

%prep
%setup -q -n GRNOC-WebService-%{version}

%build
%{__perl} Makefile.PL PREFIX="%{buildroot}%{_prefix}" INSTALLDIRS="vendor"
make

%install
rm -rf $RPM_BUILD_ROOT

%{__install} -d -p %{buildroot}/etc/grnoc/webservice/

%{__install} conf/config.xml %{buildroot}/etc/grnoc/webservice/config.xml

make pure_install

# clean up buildroot
find %{buildroot} -name .packlist -exec %{__rm} {} \;

%{_fixperms} $RPM_BUILD_ROOT/*

%check
make test

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(644, root, root, -)
%{perl_vendorlib}/GRNOC/WebService.pm 
%{perl_vendorlib}/GRNOC/WebService/Dispatcher.pm
%{perl_vendorlib}/GRNOC/WebService/Method.pm
%{perl_vendorlib}/GRNOC/WebService/RemoteMethod.pm
%{perl_vendorlib}/GRNOC/WebService/Regex.pm
%{perl_vendorlib}/GRNOC/WebService/Method/CDS.pm
%{perl_vendorlib}/GRNOC/WebService/Method/JIT.pm
%doc %{_mandir}/man3/GRNOC::WebService.3pm.gz
%doc %{_mandir}/man3/GRNOC::WebService::Dispatcher.3pm.gz
%doc %{_mandir}/man3/GRNOC::WebService::Method.3pm.gz
%doc %{_mandir}/man3/GRNOC::WebService::RemoteMethod.3pm.gz
%doc %{_mandir}/man3/GRNOC::WebService::Regex.3pm.gz
%doc %{_mandir}/man3/GRNOC::WebService::Method::CDS.3pm.gz
%doc %{_mandir}/man3/GRNOC::WebService::Method::JIT.3pm.gz
%config(noreplace) /etc/grnoc/webservice/config.xml
%attr(644, root, root) /etc/grnoc/webservice/config.xml
%dir %attr(755, root, root) /etc/grnoc/webservice/

%changelog
* Mon Jun 13 2011 mrmccrac 1.1.1-1
- Specfile autogenerated by cpanspec 1.77.
