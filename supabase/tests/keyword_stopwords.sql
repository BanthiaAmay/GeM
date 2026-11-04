-- Run after all migrations in an isolated test database.
do $$begin
 if public.keyword_matches('Comprehensive Maintenance Service of AC','Service') then raise exception 'Generic word alone matched'; end if;
 if public.keyword_matches('Custom Bid for Services - Repair','Custom Bid') then raise exception 'Generic phrase matched'; end if;
 if not public.keyword_matches('Security Manpower Service','Security services') then raise exception 'Mixed keyword lost its real word'; end if;
 if not public.keyword_matches('Repair and Maintenance Service','Repair and maintenance') then raise exception 'Supply group keyword broken'; end if;
 if not public.keyword_matches('LED Luminaire For Road And Street Lights','LED lights') then raise exception 'Multi-word keyword broken'; end if;
 if not public.keyword_matches('Desktop Computers','Computer') then raise exception 'Plural match broken'; end if;
 if public.keyword_matches('Open tender','pen') then raise exception 'Word-start rule broken'; end if;
end $$;
