import { NextResponse } from 'next/server';
import { updateProduct } from '../../database/products';

export async function PUT(request: Request) {
  const requestBody = await request.json();
  const { id, name, image, price } = requestBody;
  const updatedProduct = await updateProduct(id, name, image, price);
  if (updatedProduct) {
    return NextResponse.json(updatedProduct);
  } else {
    return NextResponse.json(
      { error: 'Updating database failed' },
      { status: 500 },
    );
  }
}
