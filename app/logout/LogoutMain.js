'use client';

import { signOut } from 'next-auth/react';
import { useEffect, useState } from 'react';

export default function LogoutMain() {
  const [logoutFailure, setLogoutFailure] = useState('');

  useEffect(() => {
    setTimeout(() => {
      signOut({ callbackUrl: '/' })
        .then()
        .catch((error) => setLogoutFailure(error));
    }, 500);
  }, []);

  return (
    <div className="h-[65vh] flex  flex-col justify-center">
      <h1 className="text-6xl font-extrabold text-center mb-10">Logging out</h1>
      <p className=" text-black text-[25px] font-normal text-center">
        You will be redirected to the main page shortly...
      </p>
      {logoutFailure && (
        <p className="text-red-500 text-[25px] font-bold text-center">
          Error: Logout failed
        </p>
      )}
    </div>
  );
}
